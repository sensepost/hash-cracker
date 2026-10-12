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


def process_stream(stream: BinaryIO, input_kind: str) -> int:
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
                return 1
            encoded = record[len(HEX_PREFIX) : -1]
            if len(encoded) % 2:
                write_error(line_number, "odd-length $HEX record")
                return 1
            record = binascii.unhexlify(encoded)
            if any(value in record for value in (b"\x00", b"\n", b"\r")):
                write_error(
                    line_number,
                    "NUL, LF and CR bytes cannot be transformed as text lines",
                )
                return 1

        if b"\x00" in record or b"\r" in record:
            write_error(line_number, "NUL and CR bytes cannot be transformed as text lines")
            return 1

        sys.stdout.buffer.write(record + b"\n")

    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--input-kind", choices=("potfile", "wordlist"), default="potfile"
    )
    parser.add_argument("path", nargs="?", default="-")
    args = parser.parse_args()

    if args.path == "-":
        return process_stream(sys.stdin.buffer, args.input_kind)

    try:
        with open(args.path, "rb") as stream:
            return process_stream(stream, args.input_kind)
    except OSError as error:
        message = error.strerror or str(error)
        sys.stderr.write(f"plaintext reader: {args.path}: {message}\n")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
