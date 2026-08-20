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
HASHCAT_WRAPPER="$TMP_DIR/hashcat-wrapper"
SESSION_COUNTER="$TMP_DIR/hashcat-session-counter"
HASH='5f4dcc3b5aa765d61d8327deb882cf99'
COMBINATOR_HASH='4594e41c9841aef79e064bcd75c9b7ee'
MASK_HASH='0cc175b9c0f1b6a831c399e269772661'
HYBRID_HASH='69b651400e51e98c6f3c510a3a9881bf'

mkdir -p "$INPUT_DIR" "$LOG_DIR" "$TMP_DIR/home"
printf 'password\n' >"$WORDLIST"
printf 'word\n' >"$WORDLIST2"

{
    printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail'
    printf 'COUNTER_FILE=%q\n' "$SESSION_COUNTER"
    printf '%s\n' 'counter=0' 'if [ -s "$COUNTER_FILE" ]; then read -r counter <"$COUNTER_FILE"; fi'
    printf '%s\n' 'counter=$((counter + 1))' 'printf "%s\\n" "$counter" >"$COUNTER_FILE"'
    printf 'exec %q "--session=hash-cracker-integration-$counter" "$@"\n' "$HASHCAT_BIN"
} >"$HASHCAT_WRAPPER"
chmod 700 "$HASHCAT_WRAPPER"

{
    printf 'HASHCAT=(%q)\n' "$HASHCAT_WRAPPER"
    printf 'DEVICE=%q\n' "$INTEGRATION_DEVICE"
    printf 'HASHTYPE=0\n'
    printf 'HASHLIST=%q\n' "$HASHLIST"
    printf 'POTFILE=%q\n' "$POTFILE"
    printf 'WORDLIST=%q\n' "$WORDLIST"
    printf 'WORDLIST2=%q\n' "$WORDLIST2"
} >"$CONFIG_PATH"

run_hash_cracker() {
    local name="$1"
    local input="$2"
    local command="$3"
    local run_log="$TMP_DIR/$name.log"

    echo "[integration] running the real Hashcat $name path"
    if [ -n "$input" ]; then
        if ! printf '%s' "$input" | script -qefc "$command" "$run_log" >/dev/null 2>&1; then
            echo "[integration] $name execution failed." >&2
            cat "$run_log" >&2
            exit 1
        fi
    elif ! script -qefc "$command" "$run_log" >/dev/null 2>&1; then
        echo "[integration] $name execution failed." >&2
        cat "$run_log" >&2
        exit 1
    fi
}

assert_cracked() {
    local name="$1"
    local hash="$2"
    local plaintext="$3"
    local run_log="$TMP_DIR/$name.log"

    if ! grep -Fxq "${hash}:${plaintext}" "$POTFILE"; then
        echo "[integration] $name did not write the expected result to the potfile." >&2
        cat "$run_log" >&2
        echo "[integration] potfile contents:" >&2
        cat "$POTFILE" >&2
        exit 1
    fi
}

set_hash_case() {
    local hash="$1"

    printf '%s\n' "$hash" >"$HASHLIST"
    : >"$POTFILE"
}

printf -v WORDLIST_COMMAND 'env HOME=%q HASH_CRACKER_CONFIG=%q SESSION_LOG_DIR=%q NO_COLOR=1 ./hash-cracker.sh --job 2' \
    "$TMP_DIR/home" "$CONFIG_PATH" "$LOG_DIR"
set_hash_case "$HASH"
run_hash_cracker wordlist-rules $'S\n' "$WORDLIST_COMMAND"
assert_cracked wordlist-rules "$HASH" password

printf -v MASK_COMMAND 'env HOME=%q HASH_CRACKER_CONFIG=%q SESSION_LOG_DIR=%q NO_COLOR=1 ./hash-cracker.sh --job 21' \
    "$TMP_DIR/home" "$CONFIG_PATH" "$LOG_DIR"
set_hash_case "$MASK_HASH"
run_hash_cracker mask $'1\ny\n' "$MASK_COMMAND"
assert_cracked mask "$MASK_HASH" a

printf -v HYBRID_COMMAND 'env HOME=%q HASH_CRACKER_CONFIG=%q SESSION_LOG_DIR=%q NO_COLOR=1 ./hash-cracker.sh --job 6' \
    "$TMP_DIR/home" "$CONFIG_PATH" "$LOG_DIR"
set_hash_case "$HYBRID_HASH"
run_hash_cracker hybrid $'S\n' "$HYBRID_COMMAND"
assert_cracked hybrid "$HYBRID_HASH" 'Password 0000'

printf -v COMBINATOR_COMMAND 'env HOME=%q HASH_CRACKER_CONFIG=%q SESSION_LOG_DIR=%q NO_COLOR=1 START=8 ./hash-cracker.sh --job 8' \
    "$TMP_DIR/home" "$CONFIG_PATH" "$LOG_DIR"
set_hash_case "$COMBINATOR_HASH"
run_hash_cracker combinator '' "$COMBINATOR_COMMAND"
assert_cracked combinator "$COMBINATOR_HASH" passwordword

echo "[integration] real Hashcat mask, wordlist/rules, hybrid, and combinator executions passed"
