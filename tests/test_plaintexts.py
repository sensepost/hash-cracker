"""Byte-level contract for shared potfile and wordlist decoding."""
import os
import subprocess
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
READER = REPO / "scripts" / "plaintexts.py"


class PlaintextTests(unittest.TestCase):
    def decode(self, data, kind="potfile", skip_unrepresentable_hex=False):
        command = [sys.executable, str(READER)]
        if skip_unrepresentable_hex:
            command.append("--skip-unrepresentable-hex")
        command.extend(("--input-kind", kind))
        return subprocess.run(
            command,
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

    def test_processor_mode_skips_valid_hex_controls_and_preserves_safe_records(self):
        result = self.decode(
            b"h:first\n"
            b"h:$HEX[610062]\n"
            b"h:$HEX[610a62]\n"
            b"h:$HEX[610d62]\n"
            b"h:$HEX[]\n"
            b"h:last",
            skip_unrepresentable_hex=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, b"first\n\nlast\n")
        self.assertEqual(
            result.stderr,
            b"plaintext reader: line 2: skipping valid $HEX candidate with decoded "
            b"NUL byte(s); it cannot be transformed as a text line\n"
            b"plaintext reader: line 3: skipping valid $HEX candidate with decoded "
            b"LF byte(s); it cannot be transformed as a text line\n"
            b"plaintext reader: line 4: skipping valid $HEX candidate with decoded "
            b"CR byte(s); it cannot be transformed as a text line\n"
            b"plaintext reader: skipped 3 valid $HEX candidate(s) with "
            b"unrepresentable decoded bytes\n",
        )

    def test_processor_mode_keeps_wordlist_binary_skip_and_fatal_checks(self):
        wordlist = self.decode(
            b"a:b\n$HEX[410a42]\nlast\n",
            "wordlist",
            skip_unrepresentable_hex=True,
        )
        self.assertEqual(wordlist.returncode, 0, wordlist.stderr)
        self.assertEqual(wordlist.stdout, b"a:b\nlast\n")
        self.assertIn(b"line 2: skipping valid $HEX candidate", wordlist.stderr)

        malformed = self.decode(
            b"h:before\nh:$HEX[00]\nh:$HEX[610]\nh:after\n",
            skip_unrepresentable_hex=True,
        )
        self.assertEqual(malformed.returncode, 1)
        self.assertEqual(malformed.stdout, b"before\n")
        self.assertEqual(
            malformed.stderr,
            b"plaintext reader: line 2: skipping valid $HEX candidate with decoded "
            b"NUL byte(s); it cannot be transformed as a text line\n"
            b"plaintext reader: line 3: odd-length $HEX record\n"
            b"plaintext reader: skipped 1 valid $HEX candidate(s) with "
            b"unrepresentable decoded bytes\n",
        )

        for data, diagnostic in (
            (b"h:raw\x00word\n", b"NUL and CR bytes cannot be transformed"),
            (b"h:raw\rword\n", b"NUL and CR bytes cannot be transformed"),
        ):
            with self.subTest(data=data):
                raw = self.decode(data, skip_unrepresentable_hex=True)
                self.assertEqual(raw.returncode, 1)
                self.assertEqual(raw.stdout, b"")
                self.assertIn(diagnostic, raw.stderr)

    def test_processor_mode_fails_when_every_record_is_unrepresentable(self):
        result = self.decode(
            b"h:$HEX[00]\nh:$HEX[0a]\nh:$HEX[0d]\n",
            skip_unrepresentable_hex=True,
        )
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, b"")
        self.assertIn(b"skipped 3 valid $HEX candidate(s)", result.stderr)
        self.assertIn(b"no transformable plaintext records remain", result.stderr)


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

    def run_job(self, job, input_data=None):
        return subprocess.run(
            ["/bin/bash", "./hash-cracker.sh", "--no-session-log", "--job", str(job)],
            cwd=REPO,
            env=self.env,
            input=input_data,
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

    def test_job_9_skips_binary_candidates_and_processes_safe_records(self):
        self.potfile.write_bytes(
            b"hash:ordinary\n"
            b"hash:$HEX[610062]\n"
            b"hash:later\n"
        )

        result = self.run_job(9)

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(
            "plaintext reader: line 2: skipping valid $HEX candidate with decoded NUL",
            result.stderr,
        )
        self.assertIn("skipped 1 valid $HEX candidate(s)", result.stderr)
        self.assertTrue(self.hashcat_calls.exists())
        self.assertEqual(
            (self.capture_dir / "input-1").read_bytes(), b"later\nordinary\n"
        )
        self.assertEqual(list(self.tmp_dir.iterdir()), [])

    def test_jobs_9_10_and_19_all_binary_candidates_skip_hashcat_and_clean(self):
        for job in (9, 10, 19):
            with self.subTest(job=job):
                self.potfile.write_bytes(b"hash:$HEX[610062]\n")
                result = self.run_job(job)

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("no transformable plaintext records remain", result.stderr)
                self.assertFalse(self.hashcat_calls.exists())
                self.assertFalse(self.preprocess_capture.exists())
                self.assertEqual(list(self.tmp_dir.iterdir()), [])

    def test_job_9_later_malformed_hex_after_skip_still_blocks_hashcat(self):
        self.potfile.write_bytes(
            b"hash:ordinary\n"
            b"hash:$HEX[610062]\n"
            b"hash:$HEX[610]\n"
            b"hash:later\n"
        )

        result = self.run_job(9)

        self.assertEqual(result.returncode, 1)
        self.assertIn(
            "plaintext reader: line 3: odd-length $HEX record", result.stderr
        )
        self.assertEqual(
            result.stderr.count("plaintext reader: skipped 1 valid $HEX candidate(s)"),
            1,
        )
        self.assertNotIn("610062", result.stderr)
        self.assertNotIn("ordinary", result.stderr)
        self.assertFalse(self.hashcat_calls.exists())
        self.assertEqual(list(self.tmp_dir.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
