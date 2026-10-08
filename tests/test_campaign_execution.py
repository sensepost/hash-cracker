"""Execute campaigns with controlled crashes, native stops and mutable pots."""
import json
import os
import shlex
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]

FAKE_HASHCAT = '''#!/usr/bin/env python3
import json, os, pathlib, signal, sys
root = pathlib.Path(os.environ['FIXTURE_ROOT'])
log = root / 'calls'
prior = log.read_text().splitlines() if log.exists() else []
arguments = sys.argv[1:]
if '--restore' in arguments:
    manifest = json.loads((root / 'campaign.json').read_text())
    session = next(arg.split('=', 1)[1] for arg in arguments if arg.startswith('--session='))
    command = next(command for step in manifest['steps'] for command in step['commands'] if command['session'] == session)
    arguments = command['executed_argv'][1:]
inputs = {arg: pathlib.Path(arg).read_text() for arg in arguments
          if ('/workspace/' in arg or 'hash-cracker-tmp.' in arg) and pathlib.Path(arg).is_file()}
with log.open('a') as stream:
    stream.write(json.dumps({'args': sys.argv[1:], 'inputs': inputs}) + '\\n')
if not prior:
    with (root / 'pot').open('a') as stream: stream.write('new:newpassword\\n')
if len(prior) == 1:
    stop = os.environ.get('FIXTURE_STOP', '')
    if stop == 'kill': os.kill(os.getppid(), signal.SIGKILL)
    if stop in ('3', '4', '2', 'no-restore'):
        if stop in ('3', '4'):
            restore = next(arg.split('=', 1)[1] for arg in sys.argv if arg.startswith('--restore-file-path='))
            pathlib.Path(restore).write_text('checkpoint')
        sys.exit(3 if stop == 'no-restore' else int(stop))
sys.exit(1)
'''


class CampaignExecutionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='hash-cracker-recovery-')
        self.root = Path(self.temp.name)
        for name, value in [('hashes', 'hash\n'), ('pot', 'h:originalpassword\n'),
                            ('words', 'password\n'), ('words2', 'welcome\n')]:
            (self.root / name).write_text(value)
        self.fake = self.root / 'hashcat'
        self.fake.write_text(FAKE_HASHCAT)
        self.fake.chmod(0o700)
        config = self.root / 'config'
        config.write_text('\n'.join([
            f'HASHCAT=({shlex.quote(str(self.fake))})', 'DEVICE=1', 'HASHTYPE=1000',
            *[key + '=' + shlex.quote(str(self.root / value)) for key, value in
              [('HASHLIST', 'hashes'), ('POTFILE', 'pot'), ('WORDLIST', 'words'), ('WORDLIST2', 'words2')]]]))
        self.env = dict(os.environ, HASH_CRACKER_CONFIG=str(config),
                        SESSION_LOG_DIR=str(self.root / 'logs'), FIXTURE_ROOT=str(self.root),
                        PYTHONDONTWRITEBYTECODE='1', NO_COLOR='1')
        self.manifest = self.root / 'campaign.json'

    def tearDown(self):
        self.temp.cleanup()

    def run_cli(self, *args):
        return subprocess.run(['bash', './hash-cracker.sh', '--no-session-log', *map(str, args)],
                              cwd=REPO, env=self.env, capture_output=True, text=True, timeout=90)

    def calls(self):
        return [json.loads(line) for line in (self.root / 'calls').read_text().splitlines()]

    def plan(self, job=9, path=None):
        result = self.run_cli('--plan', job, '--output', path or self.manifest)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def check_stop_resume(self, stop, expected_rc, resumable):
        self.env['FIXTURE_STOP'] = stop
        self.plan()
        result = self.run_cli('--execute', self.manifest)
        self.assertEqual(result.returncode, expected_rc, result.stdout + result.stderr)
        stopped = json.loads(self.manifest.read_text())
        step = stopped['steps'][0]
        command = step['commands'][1]
        self.assertEqual(len(self.calls()), 2, 'later commands must not run after native abort')
        self.assertEqual(len(step['generated_inputs']), 1)
        resumed = self.run_cli('--resume', self.manifest)
        self.assertEqual(resumed.returncode, 0, resumed.stdout + resumed.stderr)
        calls = self.calls()
        self.assertEqual(calls[1]['inputs'], calls[2]['inputs'])
        self.assertEqual('--restore' in calls[2]['args'], resumable)
        completed = json.loads(self.manifest.read_text())['steps'][0]
        self.assertEqual(completed['commands'][1]['attempts'], 1 if resumable or stop == 'kill' else 2)
        if resumable:
            self.assertEqual(command['session'], completed['commands'][1]['session'])
            self.assertEqual(completed['commands'][1]['interruptions'][0]['exit_code'], int(stop))
        self.assertEqual(completed['state'], 'completed')
        self.assertEqual(completed['generated_inputs'], [])
        self.assertFalse(list((Path(str(self.manifest) + '.state') / 'workspace').rglob('*')))

    def test_checkpoint_stop_and_resume(self):
        self.check_stop_resume('3', 130, True)

    def test_runtime_stop_and_resume(self):
        self.check_stop_resume('4', 130, True)

    def test_abort_retries_without_restore(self):
        self.check_stop_resume('2', 2, False)

    def test_checkpoint_without_restore_fails_and_retries(self):
        self.check_stop_resume('no-restore', 3, False)

    def test_sigkill_reuses_frozen_inputs(self):
        self.check_stop_resume('kill', 137, False)

    def test_interruption_between_commands_reuses_frozen_inputs(self):
        # The config is sourced again inside the processor subshell, so this PID
        # identifies only our fixture processor, including command substitutions.
        with (self.root / 'config').open('a') as stream:
            stream.write('\nexport FIXTURE_PROCESSOR_PID=$BASHPID\n')
        binaries = self.root / 'bin'
        binaries.mkdir()
        wrapper = binaries / 'python3'
        wrapper.write_text(f'''#!{sys.executable}
import os, pathlib, signal, sys
root = pathlib.Path(os.environ['FIXTURE_ROOT'])
args = sys.argv[1:]
if len(args) > 1 and args[:2] == ['scripts/campaign.py', 'command-start']:
    if args[args.index('--command-index') + 1] == '1' and not (root / 'between-stop').exists():
        (root / 'between-stop').touch()
        os.kill(int(os.environ['FIXTURE_PROCESSOR_PID']), signal.SIGTERM)
        sys.exit(1)
os.execv({sys.executable!r}, [{sys.executable!r}, *args])
''')
        wrapper.chmod(0o700)
        self.env['PATH'] = str(binaries) + os.pathsep + self.env['PATH']
        self.plan()
        result = self.run_cli('--execute', self.manifest)
        self.assertEqual(result.returncode, 130, result.stdout + result.stderr)
        stopped = json.loads(self.manifest.read_text())['steps'][0]
        self.assertEqual(stopped['commands'][0]['state'], 'completed')
        self.assertEqual(stopped['commands'][1]['state'], 'pending')
        self.assertEqual(len(stopped['generated_inputs']), 1)
        self.assertEqual(len(self.calls()), 1)
        result = self.run_cli('--resume', self.manifest)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.calls()[0]['inputs'], self.calls()[1]['inputs'])

    def test_plan_execute_resume_via_symlink(self):
        alias = self.root / 'alias.json'
        alias.symlink_to(self.manifest)
        self.env['FIXTURE_STOP'] = '4'
        self.plan(path=alias)
        self.assertTrue(alias.is_symlink())
        result = self.run_cli('--execute', alias)
        self.assertEqual(result.returncode, 130, result.stdout + result.stderr)
        result = self.run_cli('--resume', alias)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(alias.is_symlink())
        self.assertFalse(Path(str(alias) + '.state').exists())

    def test_fingerprint_plain_and_hex_generate_same_fragments(self):
        self.env['FINGERPRINT_SEGMENT_MAX'] = '1'
        results = []
        for word in ('password', '$HEX[70617373776f7264]'):
            (self.root / 'pot').write_text('h:' + word + '\n')
            (self.root / 'calls').unlink(missing_ok=True)
            result = self.run_cli('--job', 14)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            results.append(list(self.calls()[0]['inputs'].values()))
        self.assertEqual(results[0], results[1])
        self.assertIn('p\n', results[1][0])

    def test_retention_cli_environment_and_configuration_export_decimal_json(self):
        output = self.root / 'stats.json'
        for flags, expected in [(('--session-log-keep', '08'), 8),
                                (('--session-log-keep=010',), 10),
                                (('--session-log-keep=2147483647',), 2147483647)]:
            result = self.run_cli('--dry-run', '--job', 99, '--stats-export', output, *flags)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(json.loads(output.read_text())['logging']['keep'], expected)
        self.env['SESSION_LOG_KEEP'] = '0008'
        result = self.run_cli('--dry-run', '--job', 99, '--stats-export', output)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(json.loads(output.read_text())['logging']['keep'], 8)
        with (self.root / 'config').open('a') as stream:
            stream.write('\nSESSION_LOG_KEEP=010\n')
        result = self.run_cli('--dry-run', '--job', 99, '--stats-export', output)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(json.loads(output.read_text())['logging']['keep'], 10)
        with (self.root / 'config').open('a') as stream:
            stream.write('SESSION_LOG_KEEP=2147483648\n')
        snapshot = output.read_bytes()
        result = self.run_cli('--dry-run', '--job', 99, '--stats-export', output)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(output.read_bytes(), snapshot)
