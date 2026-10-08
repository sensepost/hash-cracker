"""Byte-oriented contract for shared potfile and wordlist decoding."""
import subprocess
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


class PlaintextTests(unittest.TestCase):
    def decode(self, data, kind='potfile'):
        return subprocess.run(['awk', '-v', f'input_kind={kind}', '-f', 'scripts/plaintexts.awk'],
                              input=data, capture_output=True, cwd=REPO,
                              env={'PATH': '/usr/bin:/bin', 'LC_ALL': 'C'})

    def test_plain_and_encoded_records(self):
        result = self.decode(b'h:password\r\nh:$HEX[70617373776F7264]\nh:$HEX[613A62]\nh:$HEX[c3a9]\nh:$HEX[]\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, b'password\npassword\na:b\n\xc3\xa9\n\n')

    def test_malformed_and_unrepresentable_records_fail(self):
        for word in (b'$HEX[1]', b'$HEX[gg]', b'$HEX[41', b'$HEX[00]',
                     b'$HEX[0a]', b'$HEX[0d]', b'raw\x00word'):
            with self.subTest(word=word):
                result = self.decode(b'h:' + word + b'\n')
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, b'')
                self.assertIn(b'line 1', result.stderr)

    def test_wordlists_preserve_colons(self):
        self.assertEqual(self.decode(b'a:b\n$HEX[613A62]\n', 'wordlist').stdout, b'a:b\na:b\n')
        self.assertEqual(self.decode(b'h:salt:word\n').stdout, b'word\n')
