#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if [ -n "${HASHCAT_INTEGRATION_HASHCAT:-}" ]; then
    HASHCAT_BIN="$(command -v "$HASHCAT_INTEGRATION_HASHCAT" 2>/dev/null || true)"
else
    HASHCAT_BIN="$(command -v hashcat 2>/dev/null || true)"
fi

if [ -z "$HASHCAT_BIN" ] || [ ! -x "$HASHCAT_BIN" ]; then
    echo "[integration] executable Hashcat is required; set HASHCAT_INTEGRATION_HASHCAT to its path." >&2
    exit 1
fi

INTEGRATION_DEVICE="${HASHCAT_INTEGRATION_DEVICE:-1}"
REQUIRE_GPU="${HASHCAT_INTEGRATION_REQUIRE_GPU:-0}"
case "$REQUIRE_GPU" in
    0 | 1) ;;
    *)
        echo "[integration] HASHCAT_INTEGRATION_REQUIRE_GPU must be 0 or 1." >&2
        exit 1
        ;;
esac

HASHCAT_VERSION="$($HASHCAT_BIN --version 2>&1 | head -n 1)"
echo "[integration] $HASHCAT_VERSION"

HASHCAT_INFO="$($HASHCAT_BIN -I 2>&1)" || {
    echo "[integration] Hashcat backend discovery failed." >&2
    printf '%s\n' "$HASHCAT_INFO" >&2
    exit 1
}

if ! command -v script >/dev/null 2>&1; then
    echo "[integration] the Linux 'script' utility is required to provide a terminal for Hashcat." >&2
    exit 1
fi

if [ "$REQUIRE_GPU" = '1' ] && ! grep -Eq 'Type[. ]*:[[:space:]]+GPU' <<<"$HASHCAT_INFO"; then
    echo "[integration] a GPU backend is required for this run, but Hashcat reported none." >&2
    printf '%s\n' "$HASHCAT_INFO" >&2
    exit 1
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hash-cracker-integration.XXXXXX")"
cleanup() {
    rm -rf -- "$TMP_DIR"
}
trap cleanup EXIT

INPUT_DIR="$TMP_DIR/inputs with spaces"
LOG_DIR="$TMP_DIR/logs"
HASHLIST="$INPUT_DIR/hashes.txt"
POTFILE="$INPUT_DIR/potfile.txt"
WORDLIST="$INPUT_DIR/first wordlist.txt"
WORDLIST2="$INPUT_DIR/second wordlist.txt"
CONFIG_PATH="$TMP_DIR/hash-cracker.conf"
RUN_LOG="$TMP_DIR/run.log"
HASH='5f4dcc3b5aa765d61d8327deb882cf99'

mkdir -p "$INPUT_DIR" "$LOG_DIR" "$TMP_DIR/home"
printf '%s\n' "$HASH" >"$HASHLIST"
: >"$POTFILE"
printf 'pass\n' >"$WORDLIST"
printf 'word\n' >"$WORDLIST2"

{
    printf 'HASHCAT=(%q)\n' "$HASHCAT_BIN"
    printf 'DEVICE=%q\n' "$INTEGRATION_DEVICE"
    printf 'HASHTYPE=0\n'
    printf 'HASHLIST=%q\n' "$HASHLIST"
    printf 'POTFILE=%q\n' "$POTFILE"
    printf 'WORDLIST=%q\n' "$WORDLIST"
    printf 'WORDLIST2=%q\n' "$WORDLIST2"
} >"$CONFIG_PATH"

echo "[integration] running the real Hashcat combinator path"
printf -v INTEGRATION_COMMAND 'env HOME=%q HASH_CRACKER_CONFIG=%q SESSION_LOG_DIR=%q NO_COLOR=1 START=8 ./hash-cracker.sh --job 8' \
    "$TMP_DIR/home" "$CONFIG_PATH" "$LOG_DIR"
if ! script -qefc "$INTEGRATION_COMMAND" "$RUN_LOG" >/dev/null 2>&1; then
    echo "[integration] hash-cracker execution failed." >&2
    cat "$RUN_LOG" >&2
    exit 1
fi

if ! grep -Fxq "${HASH}:password" "$POTFILE"; then
    echo "[integration] expected password was not written to the potfile." >&2
    cat "$RUN_LOG" >&2
    echo "[integration] potfile contents:" >&2
    cat "$POTFILE" >&2
    exit 1
fi

echo "[integration] real Hashcat execution passed"
