#!/usr/bin/env python3
"""Read potfile and wordlist candidates without text decoding."""

import argparse
import binascii
import re
import sys
from typing import BinaryIO


HEX_PREFIX = b"$HEX["
HEX_RECORD = re.compile(rb"\$HEX\[[0-9a-fA-F]*\]")


def write_error(line_number: int, message: str) -> None:
    sys.stderr.buffer.write(
        f"plaintext reader: line {line_number}: {message}\n".encode("ascii")
    )


def write_skip_summary(skipped: int) -> None:
    if skipped:
        sys.stderr.buffer.write(
            f"plaintext reader: skipped {skipped} valid $HEX candidate(s) "
            "with unrepresentable decoded bytes\n".encode("ascii")
        )


def process_stream(
    stream: BinaryIO, input_kind: str, skip_unrepresentable_hex: bool = False
) -> int:
    skipped = 0
    written = 0

    for line_number, record in enumerate(stream, start=1):
        if record.endswith(b"\n"):
            record = record[:-1]
        if record.endswith(b"\r"):
            record = record[:-1]

        if input_kind == "potfile" and b":" in record:
            record = record.rpartition(b":")[2]

        if record.startswith(HEX_PREFIX):
            if HEX_RECORD.fullmatch(record) is None:
                write_error(line_number, "malformed $HEX record")
                write_skip_summary(skipped)
                return 1
            encoded = record[len(HEX_PREFIX) : -1]
            if len(encoded) % 2:
                write_error(line_number, "odd-length $HEX record")
                write_skip_summary(skipped)
                return 1
            record = binascii.unhexlify(encoded)
            unsupported = [
                name
                for value, name in (
                    (b"\x00", "NUL"),
                    (b"\n", "LF"),
                    (b"\r", "CR"),
                )
                if value in record
            ]
            if unsupported:
                if skip_unrepresentable_hex:
                    write_error(
                        line_number,
                        "skipping valid $HEX candidate with decoded "
                        f"{', '.join(unsupported)} byte(s); it cannot be "
                        "transformed as a text line",
                    )
                    skipped += 1
                    continue
                write_error(
                    line_number,
                    "NUL, LF and CR bytes cannot be transformed as text lines",
                )
                write_skip_summary(skipped)
                return 1

        if b"\x00" in record or b"\r" in record:
            write_error(line_number, "NUL and CR bytes cannot be transformed as text lines")
            write_skip_summary(skipped)
            return 1

        sys.stdout.buffer.write(record + b"\n")
        written += 1

    if skipped:
        write_skip_summary(skipped)
        if written == 0:
            sys.stderr.buffer.write(
                b"plaintext reader: no transformable plaintext records remain\n"
            )
            return 1

    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--input-kind", choices=("potfile", "wordlist"), default="potfile"
    )
    parser.add_argument(
        "--skip-unrepresentable-hex",
        action="store_true",
        help="skip valid $HEX candidates containing NUL, LF, or CR bytes",
    )
    parser.add_argument("path", nargs="?", default="-")
    args = parser.parse_args()

    if args.path == "-":
        return process_stream(
            sys.stdin.buffer, args.input_kind, args.skip_unrepresentable_hex
        )

    try:
        with open(args.path, "rb") as stream:
            return process_stream(stream, args.input_kind, args.skip_unrepresentable_hex)
    except OSError as error:
        message = error.strerror or str(error)
        sys.stderr.write(f"plaintext reader: {args.path}: {message}\n")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
