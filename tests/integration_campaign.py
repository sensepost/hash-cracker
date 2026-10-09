#!/usr/bin/env python3
"""Opt-in real Hashcat runtime checkpoint and restore contract."""
import base64
import hashlib
import json
import os
import random
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


def main():
    with tempfile.TemporaryDirectory(prefix='hash-cracker-checkpoint-') as directory:
        root = Path(directory)
        rng = random.Random(20261008)
        seed = ''.join(rng.choice('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ') for _ in range(50000))
        salt = b'checkpoint'
        digest = hashlib.pbkdf2_hmac('sha256', b'outside-the-candidate-space-123456789', salt, 10000, dklen=24)
        encoded = lambda value: base64.b64encode(value).decode('ascii')
        (root / 'hashes').write_text(f'sha256:10000:{encoded(salt)}:{encoded(digest)}\n')
        (root / 'pot').write_text('seed:' + seed + '\n')
        for name in ('words', 'words2'):
            (root / name).write_text('password\n')
        shim = root / 'hashcat'
        shim.write_text('''#!/usr/bin/env python3
import json, os, pathlib, subprocess, sys
root = pathlib.Path(os.environ['CHECKPOINT_ROOT'])
with (root / 'calls').open('a') as stream: stream.write(json.dumps(sys.argv[1:]) + '\\n')
args = sys.argv[1:]
if '--restore' not in args: args += ['--runtime=1']
sys.exit(subprocess.run([os.environ['CHECKPOINT_HASHCAT'], *args]).returncode)
''')
        shim.chmod(0o700)
        config = root / 'config'
        config.write_text('\n'.join([
            f'HASHCAT=({shlex.quote(str(shim))})',
            'DEVICE=' + shlex.quote(os.environ.get('HASHCAT_INTEGRATION_DEVICE', '1')),
            'HASHTYPE=10900',
            *[key + '=' + shlex.quote(str(root / value)) for key, value in
              [('HASHLIST', 'hashes'), ('POTFILE', 'pot'), ('WORDLIST', 'words'), ('WORDLIST2', 'words2')]]]))
        env = dict(os.environ, HASH_CRACKER_CONFIG=str(config),
                   SESSION_LOG_DIR=str(root / 'logs'), CHECKPOINT_ROOT=str(root),
                   CHECKPOINT_HASHCAT=sys.argv[1], FINGERPRINT_SEGMENT_MAX='4', NO_COLOR='1')
        manifest = root / 'campaign.json'

        def run(*args):
            result = subprocess.run(['bash', './hash-cracker.sh', '--no-session-log', *args],
                                    cwd=REPO, env=env, capture_output=True, text=True, timeout=150)
            return result

        result = run('--plan', '14', '--output', str(manifest))
        assert result.returncode == 0, result.stdout + result.stderr
        result = run('--execute', str(manifest))
        assert result.returncode == 130, result.stdout + result.stderr
        stopped = json.loads(manifest.read_text())['steps'][0]
        command = stopped['commands'][0]
        assert command['exit_code'] == 4 and command['state'] == 'interrupted', command
        restore = Path(command['restore_file'])
        assert restore.is_file() and restore.stat().st_size > 0
        inputs = stopped['generated_inputs']
        assert inputs
        before = {item['path']: Path(item['path']).read_bytes() for item in inputs}
        checkpoint = restore.read_bytes()
        restore.unlink()
        missing = run('--resume', str(manifest))
        assert missing.returncode == 1, missing.stdout + missing.stderr
        assert 'campaign checkpoint is missing' in missing.stdout + missing.stderr
        missing_state = json.loads(manifest.read_text())
        missing_command = missing_state['steps'][0]['commands'][0]
        assert missing_state['status'] == 'paused'
        assert missing_state['steps'][0]['state'] == 'interrupted'
        assert missing_command['state'] == 'interrupted'
        assert missing_command['attempts'] == 1
        assert missing_command['session'] == command['session']
        assert not restore.exists()
        assert before == {path: Path(path).read_bytes() for path in before}
        calls = [json.loads(line) for line in (root / 'calls').read_text().splitlines()]
        assert len(calls) == 1, calls

        restore.write_bytes(checkpoint)
        result = run('--resume', str(manifest))
        assert result.returncode == 130, result.stdout + result.stderr
        resumed = json.loads(manifest.read_text())['steps'][0]['commands'][0]
        assert resumed['exit_code'] == 4 and resumed['state'] == 'interrupted', resumed
        assert resumed['attempts'] == 1 and resumed['session'] == command['session']
        assert [item['exit_code'] for item in resumed['interruptions']] == [4, 4]
        assert before == {path: Path(path).read_bytes() for path in before}
        calls = [json.loads(line) for line in (root / 'calls').read_text().splitlines()]
        assert len(calls) == 2 and '--restore' in calls[1], calls
        print('[integration] real Hashcat checkpoint loss failed closed, then restore reused the same session and candidate bytes')


if __name__ == '__main__':
    main()
