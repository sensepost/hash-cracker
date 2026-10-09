"""Regression contracts for durable campaign state and numeric retention."""
import argparse
import contextlib
import io
import json
import os
import shlex
import subprocess
import time
import unittest
from unittest import mock
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

    def start_and_record(self):
        with contextlib.redirect_stdout(io.StringIO()):
            campaign.command_start(self.args())
        command = campaign.load_manifest(str(self.manifest))['steps'][0]['commands'][0]
        argv = command['argv'] + [
            f"--session={command['session']}",
            f"--restore-file-path={command['restore_file']}",
        ]
        campaign.record_command(self.args(preview=shlex.join(argv)))
        return command

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

    def test_missing_accepted_checkpoint_fails_before_manifest_mutation(self):
        with contextlib.redirect_stdout(io.StringIO()):
            campaign.command_start(self.args())
        command = campaign.load_manifest(str(self.manifest))['steps'][0]['commands'][0]
        restore = Path(command['restore_file'])
        restore.write_bytes(b'accepted checkpoint')
        campaign.command_finish(self.args(state='interrupted', exit_code=4, duration=3))
        campaign.update_step(self.args(state='interrupted', exit_code=130, duration=3,
                                       commands_file=None))

        restore.unlink()
        snapshot = self.manifest.read_bytes()
        for operation in (campaign.mark_running, campaign.command_start):
            with self.subTest(operation=operation.__name__):
                with self.assertRaisesRegex(campaign.CampaignError, 'checkpoint is missing'):
                    operation(self.args())
                self.assertEqual(self.manifest.read_bytes(), snapshot)

        manifest = json.loads(snapshot)
        manifest['steps'][0]['commands'][0]['session'] = None
        manifest['steps'][0]['commands'][0]['restore_file'] = None
        self.manifest.write_text(json.dumps(manifest), encoding='utf-8')
        malformed_snapshot = self.manifest.read_bytes()
        for operation in (campaign.mark_running, campaign.command_start):
            with self.subTest(operation=operation.__name__, malformed=True):
                with self.assertRaisesRegex(campaign.CampaignError, 'invalid paused-command'):
                    operation(self.args())
                self.assertEqual(self.manifest.read_bytes(), malformed_snapshot)

    def test_malformed_running_attempt_fails_before_step_mutation(self):
        self.start_and_record()
        manifest = campaign.load_manifest(str(self.manifest))
        manifest['steps'][0]['commands'][0]['session'] = None
        campaign.write_manifest(str(self.manifest), manifest)
        snapshot = self.manifest.read_bytes()

        for operation in (campaign.mark_running, campaign.command_start):
            with self.subTest(operation=operation.__name__):
                with self.assertRaisesRegex(campaign.CampaignError, 'invalid running-command'):
                    operation(self.args())
                self.assertEqual(self.manifest.read_bytes(), snapshot)

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
        command = self.start_and_record()
        Path(command['restore_file']).write_bytes(b'checkpoint')
        campaign.command_finish(self.args(state='interrupted', exit_code=3, duration=1))
        with contextlib.redirect_stdout(output := io.StringIO()):
            campaign.command_start(self.args())
        first_resume = campaign.load_manifest(str(self.manifest))['steps'][0]['commands'][0]
        self.assertEqual(output.getvalue().strip().split('\t')[3], '1')
        self.assertEqual(first_resume['session'], command['session'])
        self.assertEqual(first_resume['attempts'], 1)

        campaign.command_finish(self.args(state='interrupted', exit_code=4, duration=2))
        with contextlib.redirect_stdout(output := io.StringIO()):
            campaign.command_start(self.args())
        second_resume = campaign.load_manifest(str(self.manifest))['steps'][0]['commands'][0]
        self.assertEqual(output.getvalue().strip().split('\t')[3], '1')
        self.assertEqual(second_resume['session'], command['session'])
        self.assertEqual(second_resume['attempts'], 1)
        campaign.command_finish(self.args(state='completed', exit_code=1, duration=3))

        completed = campaign.load_manifest(str(self.manifest))['steps'][0]['commands'][0]
        self.assertEqual(len(completed['attempt_outcomes']), 1)
        outcome = completed['attempt_outcomes'][0]
        self.assertEqual((outcome['attempt'], outcome['session']), (1, command['session']))
        self.assertEqual((outcome['outcome'], outcome['exit_code']), ('completed', 1))
        self.assertEqual(outcome['duration_seconds'], 6)
        self.assertEqual(
            [(event['attempt'], event['session'], event['exit_code'])
             for event in completed['interruptions']],
            [(1, command['session'], 3), (1, command['session'], 4)],
        )
        with contextlib.redirect_stdout(io.StringIO()):
            campaign.command_start(self.args())
        self.assertEqual(
            len(campaign.load_manifest(str(self.manifest))['steps'][0]['commands'][0]['attempt_outcomes']),
            1,
        )

    def test_failed_retry_attempts_are_preserved_without_argv_copy(self):
        first = self.start_and_record()
        campaign.command_finish(self.args(state='failed', exit_code=7, duration=5))
        second = self.start_and_record()
        self.assertNotEqual(first['session'], second['session'])
        campaign.command_finish(self.args(state='completed', exit_code=1, duration=4))

        command = campaign.load_manifest(str(self.manifest))['steps'][0]['commands'][0]
        outcomes = command['attempt_outcomes']
        self.assertEqual(len(outcomes), 2)
        self.assertEqual(
            [(item['attempt'], item['session'], item['outcome'], item['exit_code'],
              item['duration_seconds']) for item in outcomes],
            [(1, first['session'], 'failed', 7, 5),
             (2, second['session'], 'completed', 1, 4)],
        )
        self.assertTrue(all(len(item['argv_sha256']) == 64 for item in outcomes))
        self.assertTrue(all('argv' not in item for item in outcomes))

    def test_completion_write_failure_keeps_recovery_artifacts_and_running_state(self):
        command = self.start_and_record()
        restore = Path(command['restore_file'])
        restore.write_bytes(b'checkpoint')
        campaign.command_finish(self.args(state='interrupted', exit_code=4, duration=3))
        with contextlib.redirect_stdout(io.StringIO()):
            campaign.command_start(self.args())

        resumed = campaign.load_manifest(str(self.manifest))['steps'][0]['commands'][0]
        argv_file = campaign.campaign_state_dir(str(self.manifest)) / f"{resumed['session']}.argv"
        self.assertTrue(restore.is_file())
        self.assertTrue(argv_file.is_file())
        with mock.patch.object(campaign, 'write_manifest', side_effect=OSError('disk full')):
            with self.assertRaisesRegex(OSError, 'disk full'):
                campaign.command_finish(self.args(state='completed', exit_code=1, duration=2))

        durable = campaign.load_manifest(str(self.manifest))['steps'][0]['commands'][0]
        self.assertEqual(durable['state'], 'running')
        self.assertEqual(durable['attempts'], 1)
        self.assertTrue(restore.is_file())
        self.assertTrue(argv_file.is_file())

    def test_cleanup_failure_keeps_completion_durable_and_resume_only_retries_cleanup(self):
        command = self.start_and_record()
        restore = Path(command['restore_file'])
        restore.write_bytes(b'checkpoint')
        campaign.command_finish(self.args(state='interrupted', exit_code=4, duration=3))
        with contextlib.redirect_stdout(io.StringIO()):
            campaign.command_start(self.args())

        current = campaign.load_manifest(str(self.manifest))['steps'][0]['commands'][0]
        argv_file = campaign.campaign_state_dir(str(self.manifest)) / f"{current['session']}.argv"
        original_unlink = Path.unlink

        def fail_restore_unlink(path, *args, **kwargs):
            if path == restore:
                raise PermissionError('cleanup blocked')
            return original_unlink(path, *args, **kwargs)

        with mock.patch.object(Path, 'unlink', fail_restore_unlink):
            with self.assertRaisesRegex(campaign.CampaignError, 'cleanup failed'):
                campaign.command_finish(self.args(state='completed', exit_code=1, duration=2))

        durable = campaign.load_manifest(str(self.manifest))['steps'][0]['commands'][0]
        self.assertEqual(durable['state'], 'completed')
        self.assertEqual(durable['attempt_outcomes'][0]['outcome'], 'completed')
        self.assertTrue(restore.is_file())
        self.assertTrue(argv_file.is_file())

        with mock.patch.object(
            campaign,
            'ensure_private_directory',
            side_effect=campaign.CampaignError('private directory ownership changed'),
        ):
            with self.assertRaisesRegex(campaign.CampaignError, 'ownership changed'):
                campaign.command_start(self.args())
        still_completed = campaign.load_manifest(str(self.manifest))['steps'][0]['commands'][0]
        self.assertEqual(still_completed['state'], 'completed')
        self.assertTrue(restore.is_file())
        self.assertTrue(argv_file.is_file())

        with contextlib.redirect_stdout(output := io.StringIO()):
            campaign.command_start(self.args())
        self.assertTrue(output.getvalue().startswith('completed\t'))
        retried = campaign.load_manifest(str(self.manifest))['steps'][0]['commands'][0]
        self.assertEqual(retried['state'], 'completed')
        self.assertEqual(retried['attempts'], 1)
        self.assertEqual(retried['attempt_outcomes'], durable['attempt_outcomes'])
        self.assertFalse(restore.exists())
        self.assertFalse(argv_file.exists())

    def test_legacy_manifest_without_attempt_outcomes_remains_readable(self):
        manifest = json.loads(self.manifest.read_text(encoding='utf-8'))
        del manifest['steps'][0]['commands'][0]['attempt_outcomes']
        self.manifest.write_text(json.dumps(manifest), encoding='utf-8')
        loaded = campaign.load_manifest(str(self.manifest))
        self.assertEqual(loaded['steps'][0]['commands'][0]['attempt_outcomes'], [])

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

    def test_campaign_decimal_controls_are_ascii_locale_independent_and_bounded(self):
        locales = subprocess.run(
            ['locale', '-a'], capture_output=True, text=True, check=False
        ).stdout.splitlines()
        non_c_locale = next(
            (value for value in locales if value not in ('C', 'POSIX', 'C.utf8', 'C.UTF-8')),
            None,
        )
        env = dict(os.environ)
        if non_c_locale:
            env['LC_ALL'] = non_c_locale

        accepted = [
            ('1', '64', '1'),
            ('08', '64', '8'),
            ('010', '64', '10'),
            ('64', '64', '64'),
            ('99', '99', '99'),
        ]
        for value, maximum, expected in accepted:
            with self.subTest(value=value, maximum=maximum):
                result = subprocess.run(
                    [
                        'bash', '-c',
                        'source hash-cracker.sh; normalize_bounded_positive_decimal "$1" "$2"',
                        '_', value, maximum,
                    ], cwd=fixtures.REPO_ROOT, env=env, capture_output=True, text=True,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), expected)

        rejected = [
            ('', '64'), ('0', '64'), ('00', '64'), ('65', '64'), ('100', '99'),
            ('999999999999999999999999999999999999', '99'),
            ('x', '64'), ('８', '64'), ('٨', '64'),
        ]
        for value, maximum in rejected:
            with self.subTest(value=value, maximum=maximum):
                result = subprocess.run(
                    [
                        'bash', '-c',
                        'source hash-cracker.sh; normalize_bounded_positive_decimal "$1" "$2"',
                        '_', value, maximum,
                    ], cwd=fixtures.REPO_ROOT, env=env, capture_output=True, text=True,
                )
                self.assertNotEqual(result.returncode, 0)
