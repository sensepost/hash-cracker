#!/usr/bin/env python3
"""Opt-in real Hashcat runtime checkpoint and restore contract."""
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
        (root / 'hashes').write_text(hashlib.md5(b'outside-the-candidate-space-123456789').hexdigest() + '\n')
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
            'HASHTYPE=0',
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
        result = run('--resume', str(manifest))
        assert result.returncode == 130, result.stdout + result.stderr
        resumed = json.loads(manifest.read_text())['steps'][0]['commands'][0]
        assert resumed['exit_code'] == 4 and resumed['state'] == 'interrupted', resumed
        assert resumed['attempts'] == 1 and resumed['session'] == command['session']
        assert [item['exit_code'] for item in resumed['interruptions']] == [4, 4]
        assert before == {path: Path(path).read_bytes() for path in before}
        calls = [json.loads(line) for line in (root / 'calls').read_text().splitlines()]
        assert len(calls) == 2 and '--restore' in calls[1], calls
        print('[integration] real Hashcat saved and loaded a runtime checkpoint with the same session and candidate bytes')


if __name__ == '__main__':
    main()
