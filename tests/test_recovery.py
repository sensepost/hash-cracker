"""Regression contracts for durable campaign state and numeric retention."""
import argparse
import contextlib
import io
import json
import os
import subprocess
import time
import unittest
from pathlib import Path

import test_campaign as fixtures

campaign = fixtures.campaign


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.CampaignContractTests()
        self.fixture.setUp()
        self.root = self.fixture.root
        self.manifest = self.fixture.manifest
        args = self.fixture.create_args()
        args.workspace = str(campaign.campaign_state_dir(str(self.manifest)) / 'workspace')
        campaign.create_manifest(args)

    def tearDown(self):
        self.fixture.tearDown()

    def args(self, **kwargs):
        return argparse.Namespace(manifest=str(self.manifest), index=0,
                                  step_id='step-001', command_index=0, **kwargs)

    def test_symlink_writes_target_without_replacing_alias(self):
        alias = self.root / 'alias.json'
        alias.symlink_to(self.manifest)
        manifest = campaign.load_manifest(str(alias))
        manifest['status'] = 'paused'
        campaign.write_manifest(str(alias), manifest)
        self.assertTrue(alias.is_symlink())
        self.assertEqual(json.loads(self.manifest.read_text())['status'], 'paused')
        self.assertEqual(campaign.campaign_state_dir(str(alias)),
                         campaign.campaign_state_dir(str(self.manifest)))

    def test_export_rejects_sidecar_and_aliases_without_mutation(self):
        state = campaign.campaign_state_dir(str(self.manifest))
        lock = state / 'campaign.lock'
        lock.write_bytes(b'lock')
        symlink = self.root / 'symlink'
        symlink.symlink_to(state, target_is_directory=True)
        hardlink = self.root / 'hardlink'
        os.link(lock, hardlink)
        for path in (lock, state / 'workspace' / 'future', symlink / 'campaign.lock', hardlink):
            with self.subTest(path=path), self.assertRaisesRegex(campaign.CampaignError, 'campaign state'):
                campaign.validate_export(self.args(output=str(path)))
        campaign.validate_export(self.args(output=str(self.root / 'safe.json')))
        self.assertEqual(lock.read_bytes(), b'lock')

    def test_export_cannot_replace_lock_and_alias_cannot_acquire_it(self):
        state = campaign.campaign_state_dir(str(self.manifest))
        ready, release = state / 'owner.ready', state / 'owner.release'
        alias = self.root / 'alias.json'
        alias.symlink_to(self.manifest)
        owner = subprocess.Popen(['python3', str(fixtures.CAMPAIGN_PATH), 'lock-hold',
                                  '--manifest', str(self.manifest), '--ready', str(ready),
                                  '--release', str(release), '--owner', str(os.getpid())])
        try:
            deadline = time.monotonic() + 5
            while not ready.exists() and time.monotonic() < deadline:
                time.sleep(0.01)
            self.assertEqual(ready.read_text().strip(), 'acquired')
            lock = state / 'campaign.lock'
            inode = lock.stat().st_ino
            result = subprocess.run(['bash', '-c',
                'source hash-cracker.sh; CAMPAIGN_EXECUTE="$1"; STATSEXPORT="$2"; export_session_stats_json',
                '_', str(alias), str(lock)], cwd=fixtures.REPO_ROOT, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(lock.stat().st_ino, inode)
            competitor = subprocess.run(['python3', str(fixtures.CAMPAIGN_PATH), 'lock-hold',
                '--manifest', str(alias), '--ready', str(state / 'competitor.ready'),
                '--release', str(state / 'competitor.release'), '--owner', str(os.getpid())], timeout=5)
            self.assertEqual(competitor.returncode, 1)
            self.assertEqual((state / 'competitor.ready').read_text().strip(), 'busy')
        finally:
            release.touch()
            owner.wait(timeout=5)

    def test_multiple_generated_inputs_cleanup_and_partial_rejection(self):
        workspace = campaign.campaign_state_dir(str(self.manifest)) / 'workspace'
        paths = [workspace / 'prefix', workspace / 'suffix']
        for path in paths:
            path.write_bytes(b'candidate\n')
        campaign.register_generated_inputs(self.args(path=list(map(str, paths))))
        with self.assertRaisesRegex(campaign.CampaignError, 'set changed'):
            campaign.generated_inputs_state(self.args(path=[str(paths[0])]))
        campaign.update_step(self.args(state='completed', exit_code=0, duration=1, commands_file=None))
        self.assertFalse(any(path.exists() for path in paths))
        self.assertEqual(campaign.load_manifest(str(self.manifest))['steps'][0]['generated_inputs'], [])

    def test_started_legacy_step_without_preserved_inputs_fails_closed(self):
        with contextlib.redirect_stdout(io.StringIO()):
            campaign.command_start(self.args())
        with self.assertRaisesRegex(campaign.CampaignError, 'unregistered inputs'):
            campaign.generated_inputs_state(self.args(path=[str(self.root / 'candidate')]))

    def test_legacy_preserved_inputs_are_adopted_with_digests(self):
        path = campaign.campaign_state_dir(str(self.manifest)) / 'workspace' / 'candidate'
        path.write_bytes(b'original\n')
        with contextlib.redirect_stdout(io.StringIO()):
            campaign.command_start(self.args())
        campaign.preserve_command_inputs(self.args(path=[str(path)]))
        campaign.register_generated_inputs(self.args(path=[str(path)]))
        records = campaign.load_manifest(str(self.manifest))['steps'][0]['generated_inputs']
        self.assertEqual(records[0]['sha256'], campaign.file_fingerprint(str(path)))
        path.unlink()
        with self.assertRaisesRegex(campaign.CampaignError, 'missing'):
            campaign.register_generated_inputs(self.args(path=[str(path)]))

    def test_generated_inputs_frozen_before_command_and_checked_on_resume(self):
        path = campaign.campaign_state_dir(str(self.manifest)) / 'workspace' / 'candidate'
        path.write_bytes(b'original\n')
        args = self.args(path=[str(path)])
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            campaign.generated_inputs_state(args)
        self.assertEqual(output.getvalue().strip(), 'fresh')
        campaign.register_generated_inputs(args)
        with contextlib.redirect_stdout(io.StringIO()):
            campaign.command_start(self.args())
        manifest = campaign.load_manifest(str(self.manifest))
        manifest['steps'][0]['commands'][0]['state'] = 'failed'
        campaign.write_manifest(str(self.manifest), manifest)
        with contextlib.redirect_stdout(output := io.StringIO()):
            campaign.generated_inputs_state(args)
        self.assertEqual(output.getvalue().strip(), 'reuse')
        self.assertEqual(campaign.path_is_preserved(self.args(path=str(path))), 0)
        path.write_bytes(b'changed\n')
        with self.assertRaisesRegex(campaign.CampaignError, 'changed'):
            campaign.generated_inputs_state(args)
        path.unlink()
        with self.assertRaisesRegex(campaign.CampaignError, 'missing'):
            campaign.generated_inputs_state(args)

    def test_native_stop_keeps_session_and_attempt(self):
        for code in (3, 4):
            with self.subTest(code=code):
                with contextlib.redirect_stdout(io.StringIO()):
                    campaign.command_start(self.args())
                command = campaign.load_manifest(str(self.manifest))['steps'][0]['commands'][0]
                Path(command['restore_file']).write_bytes(b'checkpoint')
                campaign.command_finish(self.args(state='interrupted', exit_code=code, duration=1))
                with contextlib.redirect_stdout(output := io.StringIO()):
                    campaign.command_start(self.args())
                resumed = campaign.load_manifest(str(self.manifest))['steps'][0]['commands'][0]
                self.assertEqual(resumed['state'], 'running')
                self.assertEqual(resumed['session'], command['session'])
                self.assertEqual(resumed['attempts'], command['attempts'])
                self.assertEqual(output.getvalue().strip().split('\t')[3], '1')
                self.assertEqual(resumed['interruptions'][-1]['exit_code'], code)

    def test_retention_decimal_bounds_and_no_overflow_pruning(self):
        logs = self.root / 'logs'
        logs.mkdir()
        for n in range(3):
            (logs / f'session-{n}.log').write_text('keep')
        for value, expected in [('0', '0'), ('8', '8'), ('08', '8'), ('010', '10'),
                                ('2147483647', '2147483647')]:
            proc = subprocess.run(['bash', '-c', 'source hash-cracker.sh; normalize_session_log_keep "$1"', '_', value],
                                  cwd=fixtures.REPO_ROOT, capture_output=True, text=True)
            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertEqual(proc.stdout.strip(), expected)
        proc = subprocess.run(['bash', '-c', 'source hash-cracker.sh; prune_session_logs "$1" 18446744073709551616', '_', str(logs)],
                              cwd=fixtures.REPO_ROOT, capture_output=True)
        self.assertNotEqual(proc.returncode, 0)
        self.assertEqual(len(list(logs.iterdir())), 3)
