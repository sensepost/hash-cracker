"""Byte-level contract for shared potfile and wordlist decoding."""
import os
import subprocess
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
READER = REPO / "scripts" / "plaintexts.py"


class PlaintextTests(unittest.TestCase):
    def decode(self, data, kind="potfile"):
        return subprocess.run(
            [sys.executable, str(READER), "--input-kind", kind],
            input=data,
            capture_output=True,
            cwd=REPO,
            env=dict(os.environ, LC_ALL="C", PYTHONDONTWRITEBYTECODE="1"),
        )

    def test_plain_and_hex_records_preserve_bytes_and_last_colon(self):
        result = self.decode(
            b"h:salt:password\r\n"
            b"h:$HEX[70617373776f7264]\n"
            b"h:$HEX[613A62]\n"
            b"h:$HEX[c3a9]\n"
            b"h:$HEX[]\n"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, b"password\npassword\na:b\n\xc3\xa9\n\n")
        self.assertEqual(result.stderr, b"")

    def test_wordlist_preserves_colons_and_empty_records(self):
        result = self.decode(b"a:b\n$HEX[613A62]\n\nlast", "wordlist")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, b"a:b\na:b\n\nlast\n")

    def test_plain_high_bytes_and_final_record_without_newline(self):
        result = self.decode(b"h:\xff\nlast\xfe")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, b"\xff\nlast\xfe\n")

    def test_malformed_hex_and_unrepresentable_bytes_fail(self):
        cases = (
            (b"h:$HEX[gg]\n", b"malformed $HEX record"),
            (b"h:$HEX[41\n", b"malformed $HEX record"),
            (b"h:$HEX[1]\n", b"odd-length $HEX record"),
            (
                b"h:$HEX[00]\n",
                b"NUL, LF and CR bytes cannot be transformed as text lines",
            ),
            (
                b"h:$HEX[0a]\n",
                b"NUL, LF and CR bytes cannot be transformed as text lines",
            ),
            (
                b"h:$HEX[0d]\n",
                b"NUL, LF and CR bytes cannot be transformed as text lines",
            ),
            (
                b"h:raw\x00word\n",
                b"NUL and CR bytes cannot be transformed as text lines",
            ),
            (
                b"h:raw\rword\n",
                b"NUL and CR bytes cannot be transformed as text lines",
            ),
        )
        for data, diagnostic in cases:
            with self.subTest(data=data):
                result = self.decode(data)
                self.assertEqual(result.returncode, 1)
                self.assertEqual(result.stdout, b"")
                self.assertEqual(
                    result.stderr,
                    b"plaintext reader: line 1: " + diagnostic + b"\n",
                )

    def test_invalid_later_line_reports_its_number_after_prior_output(self):
        result = self.decode(b"h:valid\nh:raw\x00invalid\n")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, b"valid\n")
        self.assertEqual(
            result.stderr,
            b"plaintext reader: line 2: "
            b"NUL and CR bytes cannot be transformed as text lines\n",
        )


class PlaintextProcessorTests(unittest.TestCase):
    def setUp(self):
        import shlex
        import tempfile

        self.temp = tempfile.TemporaryDirectory(prefix="hash-cracker-plaintext-")
        self.root = Path(self.temp.name)
        self.tmp_dir = self.root / "tmp"
        self.tmp_dir.mkdir()
        self.capture_dir = self.root / "captures"
        self.capture_dir.mkdir()
        self.potfile = self.root / "potfile"
        self.hashlist = self.root / "hashes"
        self.wordlist = self.root / "words"
        self.wordlist2 = self.root / "words2"
        self.hashcat_calls = self.root / "hashcat-calls"
        self.preprocess_capture = self.root / "preprocessed-input"
        self.common_substr = self.root / "common-substr"
        self.fake_hashcat = self.root / "hashcat"

        self.hashlist.write_bytes(b"hash\n")
        self.wordlist.write_bytes(b"password\n")
        self.wordlist2.write_bytes(b"welcome\n")
        self.common_substr.write_text(
            "#!/bin/sh\n"
            "set -eu\n"
            "cp \"$4\" \"$PREPROCESS_CAPTURE\"\n"
            "printf 'generated\\n'\n"
        )
        self.common_substr.chmod(0o700)
        self.fake_hashcat.write_text(
            "#!/bin/sh\n"
            "set -eu\n"
            "printf 'call\\n' >>\"$HASHCAT_CALLS\"\n"
            "call_count=$(wc -l <\"$HASHCAT_CALLS\" | tr -d '[:space:]')\n"
            "for argument do\n"
            "    case \"$argument\" in\n"
            "        *hash-cracker-tmp.*)\n"
            "            if [ -f \"$argument\" ]; then\n"
            "                cp \"$argument\" \"$HASHCAT_CAPTURE_DIR/input-$call_count\"\n"
            "                break\n"
            "            fi\n"
            "            ;;\n"
            "    esac\n"
            "done\n"
        )
        self.fake_hashcat.chmod(0o700)
        config = self.root / "hash-cracker.conf"
        config.write_text(
            "\n".join(
                (
                    f"HASHCAT=({shlex.quote(str(self.fake_hashcat))})",
                    "DEVICE=1",
                    "HASHTYPE=1000",
                    f"HASHLIST={shlex.quote(str(self.hashlist))}",
                    f"POTFILE={shlex.quote(str(self.potfile))}",
                    f"WORDLIST={shlex.quote(str(self.wordlist))}",
                    f"WORDLIST2={shlex.quote(str(self.wordlist2))}",
                )
            )
            + "\n"
        )
        self.env = dict(
            os.environ,
            HASH_CRACKER_CONFIG=str(config),
            SESSION_LOG_DIR=str(self.root / "logs"),
            COMMON_SUBSTR_BIN=str(self.common_substr),
            HASHCAT_CALLS=str(self.hashcat_calls),
            HASHCAT_CAPTURE_DIR=str(self.capture_dir),
            PREPROCESS_CAPTURE=str(self.preprocess_capture),
            TMPDIR=str(self.tmp_dir),
            LC_ALL="C",
            NO_COLOR="1",
            PYTHONDONTWRITEBYTECODE="1",
        )

    def tearDown(self):
        self.temp.cleanup()

    def run_job(self, job):
        return subprocess.run(
            ["/bin/bash", "./hash-cracker.sh", "--no-session-log", "--job", str(job)],
            cwd=REPO,
            env=self.env,
            capture_output=True,
            text=True,
            timeout=60,
        )

    def test_jobs_10_and_19_process_plain_and_hex_candidates(self):
        self.potfile.write_bytes(
            b"hash:password123\n"
            b"hash:$HEX[70617373776f72643037]\n"
            b"hash:$HEX[c3a9]\n"
        )

        prefix_suffix = self.run_job(10)
        self.assertEqual(
            prefix_suffix.returncode, 0, prefix_suffix.stdout + prefix_suffix.stderr
        )
        self.assertEqual(
            self.preprocess_capture.read_bytes(),
            b"password07\npassword123\n\xc3\xa9\n",
        )
        self.assertEqual(self.hashcat_calls.read_text().splitlines(), ["call", "call"])

        self.hashcat_calls.unlink()
        self.preprocess_capture.unlink()
        for path in self.capture_dir.iterdir():
            path.unlink()

        digit_removal = self.run_job(19)
        self.assertEqual(
            digit_removal.returncode, 0, digit_removal.stdout + digit_removal.stderr
        )
        self.assertEqual(
            (self.capture_dir / "input-1").read_bytes(),
            b"password\npassword\n\xc3\xa9\n",
        )
        self.assertEqual(len(self.hashcat_calls.read_text().splitlines()), 10)

    def test_invalid_job_10_and_19_inputs_skip_hashcat_and_clean_candidates(self):
        for job in (10, 19):
            with self.subTest(job=job):
                self.potfile.write_bytes(b"hash:valid\nhash:raw\x00invalid\n")
                result = self.run_job(job)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("plaintext reader: line 2:", result.stderr)
                self.assertFalse(self.hashcat_calls.exists())
                self.assertFalse(self.preprocess_capture.exists())
                self.assertEqual(list(self.tmp_dir.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
