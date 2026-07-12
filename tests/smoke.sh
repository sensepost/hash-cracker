#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

TMP_DIR="$(mktemp -d /tmp/hash-cracker-smoke.XXXX)"
CONFIG_PATH="$REPO_ROOT/hash-cracker.conf"
CONFIG_BACKUP="$TMP_DIR/hash-cracker.conf.backup"

if [ -f "$CONFIG_PATH" ]; then
    cp "$CONFIG_PATH" "$CONFIG_BACKUP"
fi

restore_config() {
    if [ -f "$CONFIG_BACKUP" ]; then
        cp "$CONFIG_BACKUP" "$CONFIG_PATH"
    fi
}

cleanup() {
    restore_config
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

LAST_LOG=""
LAST_RC=0

run_case() {
    local name="$1"
    shift
    LAST_LOG="$TMP_DIR/$name.log"

    set +e
    "$@" >"$LAST_LOG" 2>&1
    LAST_RC=$?
    set -e
}

assert_rc_eq() {
    local expected="$1"
    if [ "$LAST_RC" -ne "$expected" ]; then
        echo "[FAIL] expected rc=$expected, got rc=$LAST_RC"
        cat "$LAST_LOG"
        exit 1
    fi
}

assert_contains() {
    local needle="$1"
    if ! grep -Fq -- "$needle" "$LAST_LOG"; then
        echo "[FAIL] expected output to contain: $needle"
        cat "$LAST_LOG"
        exit 1
    fi
}

assert_not_contains() {
    local needle="$1"
    if grep -Fq -- "$needle" "$LAST_LOG"; then
        echo "[FAIL] expected output not to contain: $needle"
        cat "$LAST_LOG"
        exit 1
    fi
}

fail_with_log() {
    local message="$1"
    local log_file="$2"
    echo "[FAIL] $message"
    [ -f "$log_file" ] && cat "$log_file"
    exit 1
}

echo "[smoke] help output includes self-test flag"
run_case help bash -lc "./hash-cracker.sh --help"
assert_rc_eq 1
assert_contains "--self-test / --doctor"
assert_contains "--stats-debug"
assert_contains "--stats-export-scope [latest|all]"
assert_contains "--preset [NAME]"
assert_contains "--list-presets"

echo "[smoke] stats debug flag is accepted"
run_case stats_debug bash -lc "printf '0\n' | ./hash-cracker.sh --dry-run --stats-debug"
assert_rc_eq 0
assert_contains "Stats debug output enabled"
assert_contains "Bye..."

echo "[smoke] stats export writes JSON file"
STATS_EXPORT_PATH="$TMP_DIR/stats-export.json"
run_case stats_export bash -lc "printf '0\n' | ./hash-cracker.sh --dry-run --stats-export \"$STATS_EXPORT_PATH\""
assert_rc_eq 0
if [ ! -s "$STATS_EXPORT_PATH" ]; then
    fail_with_log "stats export file was not created" "$LAST_LOG"
fi
if ! grep -Fq '"generated_at"' "$STATS_EXPORT_PATH"; then
    fail_with_log "stats export missing generated_at key" "$STATS_EXPORT_PATH"
fi
if ! grep -Fq '"schema_version": "1"' "$STATS_EXPORT_PATH"; then
    fail_with_log "stats export missing schema_version" "$STATS_EXPORT_PATH"
fi
if ! grep -Fq '"session"' "$STATS_EXPORT_PATH"; then
    fail_with_log "stats export missing session object" "$STATS_EXPORT_PATH"
fi
if ! grep -Fq '"potfile_totals"' "$STATS_EXPORT_PATH"; then
    fail_with_log "stats export missing potfile_totals object" "$STATS_EXPORT_PATH"
fi

echo "[smoke] stats export scope all includes history entries"
STATS_EXPORT_ALL_PATH="$TMP_DIR/stats-export-all.json"
run_case stats_export_all bash -lc "printf '0\n' | ./hash-cracker.sh --dry-run --stats-export \"$STATS_EXPORT_ALL_PATH\" --stats-export-scope all"
assert_rc_eq 0
if ! grep -Fq '"export_scope": "all"' "$STATS_EXPORT_ALL_PATH"; then
    fail_with_log "stats export scope all missing export_scope marker" "$STATS_EXPORT_ALL_PATH"
fi
if ! grep -Fq '"history": [' "$STATS_EXPORT_ALL_PATH"; then
    fail_with_log "stats export scope all missing history array" "$STATS_EXPORT_ALL_PATH"
fi
if ! grep -Fq '"message": "Session stats:' "$STATS_EXPORT_ALL_PATH"; then
    fail_with_log "stats export scope all missing parsed session stats message entries" "$STATS_EXPORT_ALL_PATH"
fi

echo "[smoke] invalid stats export scope fails clearly"
run_case stats_export_scope_invalid bash -lc "./hash-cracker.sh --stats-export \"$TMP_DIR/invalid-scope.json\" --stats-export-scope nope"
assert_rc_eq 1
assert_contains "Invalid value for --stats-export-scope. Use 'latest' or 'all'."

echo "[smoke] dry-run menu exits cleanly"
run_case menu_exit bash -lc "printf '0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "0. Exit"
assert_contains "99. Session stats dashboard"
assert_contains "Bye..."

echo "[smoke] list-jobs mode prints options and exits"
run_case list_jobs bash -lc "./hash-cracker.sh --dry-run --list-jobs"
assert_rc_eq 0
assert_contains "1. Brute force"
assert_contains "99. Session stats dashboard"

echo "[smoke] list-presets mode prints built-in presets and exits"
run_case list_presets bash -lc "./hash-cracker.sh --dry-run --list-presets"
assert_rc_eq 0
assert_contains "quick - Quick baseline and iteration coverage (jobs: 1,9)"
assert_contains "quick-plus - Quick coverage plus common substring pass (jobs: 1,9,11)"
assert_contains "deep - Baseline, iteration, prefix/suffix, substring, and digit-remover coverage (jobs: 1,9,10,11,19)"
assert_contains "deep-plus - Extended potfile-driven coverage with prefix/suffix and substring passes (jobs: 1,9,10,11,14,19,9)"
assert_not_contains "Mandatory modules:"
assert_not_contains "Preparing session stats"
assert_not_contains "Static parameters:"

echo "[smoke] non-interactive --job mode runs a job and exits"
run_case single_job bash -lc "./hash-cracker.sh --dry-run --job 1"
assert_rc_eq 0
assert_contains "Brute force processing done"
assert_contains "Job 1 (Brute force) completed in"

echo "[smoke] preset quick runs and exits"
run_case preset_quick bash -lc "./hash-cracker.sh --dry-run --preset quick"
assert_rc_eq 0
assert_contains "Running preset 'quick' (jobs: 1,9)"
assert_contains "Preset 'quick': running job 1 (Brute force)"
assert_contains "Preset 'quick': running job 9 (Iterate results)"
assert_contains "Brute force processing done"
assert_contains "Iteration processing done"
assert_contains "Preset 'quick' summary"
assert_contains "| 1      | Brute force"
assert_contains "| 9      | Iterate results"
assert_contains "| ok      | 0"
assert_contains "Preset: quick | planned: 2 | completed: 2 | failed: 0 | duration:"
assert_contains "Preset 'quick' completed."

echo "[smoke] preset deep-plus dry-run reaches extended jobs"
FAKE_COMMON_SUBSTR="$TMP_DIR/fake-common-substr.sh"
cat >"$FAKE_COMMON_SUBSTR" <<EOF
#!/usr/bin/env bash
cat >/dev/null
printf 'preview\n'
EOF
chmod +x "$FAKE_COMMON_SUBSTR"

echo "[smoke] preset quick-plus dry-run reaches common substring job"
run_case preset_quick_plus bash -lc "COMMON_SUBSTR_BIN=\"$FAKE_COMMON_SUBSTR\" ./hash-cracker.sh --dry-run --preset quick-plus"
assert_rc_eq 0
assert_contains "Running preset 'quick-plus' (jobs: 1,9,11)"
assert_contains "Preset 'quick-plus': running job 11 (Common substring (advise: first run steps above))"
assert_contains "Preset 'quick-plus' completed."

run_case preset_deep_plus bash -lc "COMMON_SUBSTR_BIN=\"$FAKE_COMMON_SUBSTR\" ./hash-cracker.sh --dry-run --preset deep-plus"
assert_rc_eq 0
assert_contains "Running preset 'deep-plus' (jobs: 1,9,10,11,14,19,9)"
assert_contains "Preset 'deep-plus': running job 10 (Prefix suffix (advise: first run steps above))"
assert_contains "Preset 'deep-plus': running job 11 (Common substring (advise: first run steps above))"
assert_contains "Preset 'deep-plus' completed."

echo "[smoke] invalid preset selection fails clearly"
run_case preset_invalid bash -lc "./hash-cracker.sh --dry-run --preset nope"
assert_rc_eq 1
assert_contains "Invalid preset: nope"
assert_contains "Use --list-presets to see available presets."

echo "[smoke] preset mode exports stats"
PRESET_STATS_EXPORT_PATH="$TMP_DIR/preset-stats-export.json"
run_case preset_stats_export bash -lc "./hash-cracker.sh --dry-run --preset quick --stats-export \"$PRESET_STATS_EXPORT_PATH\""
assert_rc_eq 0
assert_contains "Preset 'quick' completed."
if [ ! -s "$PRESET_STATS_EXPORT_PATH" ]; then
    fail_with_log "preset stats export file was not created" "$LAST_LOG"
fi
if ! grep -Fq '"release": "v6.4.1 \"Run Ledger\""' "$PRESET_STATS_EXPORT_PATH"; then
    fail_with_log "preset stats export missing v6.4.1 release marker" "$PRESET_STATS_EXPORT_PATH"
fi

echo "[smoke] invalid --job selection fails clearly"
run_case single_job_invalid bash -lc "./hash-cracker.sh --dry-run --job 999"
assert_rc_eq 1
assert_contains "Invalid job selection for --job: 999"

echo "[smoke] preset and job modes are mutually exclusive"
run_case preset_job_conflict bash -lc "./hash-cracker.sh --dry-run --preset quick --job 1"
assert_rc_eq 1
assert_contains "Use either --preset or --job, not both."

echo "[smoke] prompting --job in non-interactive mode fails clearly"
run_case single_job_prompting bash -lc "./hash-cracker.sh --dry-run --job 8"
assert_rc_eq 1
assert_contains "requires interactive input and cannot run in non-interactive --job mode"

echo "[smoke] invalid option recovers back to menu"
run_case invalid_option bash -lc "printf '999\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Not valid, try again"
assert_contains "Bye..."

echo "[smoke] stats dashboard option renders"
run_case stats_dashboard bash -lc "printf '99\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Session Stats Dashboard"
assert_contains "Bye..."

echo "[smoke] dry-run combinator path prints command"
run_case combinator bash -lc "printf '8\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "[DRY-RUN]"
assert_contains "-a1"
assert_contains "Combinator processing done"

echo "[smoke] dry-run fingerprint path uses internal generator"
run_case fingerprint bash -lc "printf '14\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "would generate fingerprint fragments up to 8 chars"
assert_contains "producing combinator candidates up to 16 chars"
assert_contains "-a 1"
assert_contains "Fingerprint attack done"

echo "[smoke] fingerprint generator emits longer fragments"
FINGERPRINT_FAKE_HASHCAT="$TMP_DIR/fingerprint-fake-hashcat.sh"
FINGERPRINT_MAX_FILE="$TMP_DIR/fingerprint-max-len.txt"
FINGERPRINT_ARGS_FILE="$TMP_DIR/fingerprint-args.txt"
FINGERPRINT_POTFILE="$TMP_DIR/fingerprint.pot"
FINGERPRINT_HASHLIST="$TMP_DIR/fingerprint.hashes"

cat >"$FINGERPRINT_FAKE_HASHCAT" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "$FINGERPRINT_ARGS_FILE"
for candidate_file do :; done
awk '{ if (length(\$0) > max) max = length(\$0) } END { print max + 0 }' "\$candidate_file" > "$FINGERPRINT_MAX_FILE"
EOF
chmod +x "$FINGERPRINT_FAKE_HASHCAT"
printf 'hash:abcdefghijklmno\n' >"$FINGERPRINT_POTFILE"
printf 'hash\n' >"$FINGERPRINT_HASHLIST"

cat >"$CONFIG_PATH" <<EOF
HASHCAT=($FINGERPRINT_FAKE_HASHCAT)
DEVICE=1
HASHTYPE=1000
HASHLIST=$FINGERPRINT_HASHLIST
POTFILE=$FINGERPRINT_POTFILE
WORDLIST=wordlists/ignis-1M.txt
WORDLIST2=wordlists/ignis-1K.txt
FINGERPRINT_SEGMENT_MAX=8
EOF

run_case fingerprint_generator bash -lc "printf '14\n0\n' | ./hash-cracker.sh"
assert_rc_eq 0
assert_contains "Fingerprint attack done"
if [ "$(cat "$FINGERPRINT_MAX_FILE")" -ne 8 ]; then
    fail_with_log "fingerprint generator did not emit 8-character fragments" "$LAST_LOG"
fi
if ! grep -Fq -- "-a 1" "$FINGERPRINT_ARGS_FILE"; then
    fail_with_log "fingerprint hashcat command did not use combinator mode" "$FINGERPRINT_ARGS_FILE"
fi
restore_config

echo "[smoke] dry-run pack mask path uses python3"
run_case pack_mask_python3 bash -lc "printf '13\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "would run python3 statsgen/maskgen to produce"
assert_contains "PACK mask processing done"

echo "[smoke] dry-run pack rule path uses python3"
run_case pack_rule_python3 bash -lc "printf '12\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
if grep -Fq "would run python3 scripts/extensions/pack-linux/rulegen.py" "$LAST_LOG" \
    || grep -Fq "would run python3 scripts/extensions/pack-mac/rulegen.py" "$LAST_LOG"; then
    if ! grep -Fq "PACK rule processing done" "$LAST_LOG"; then
        fail_with_log "pack rule dry-run command printed but completion marker missing" "$LAST_LOG"
    fi
elif grep -Fq "Option 12 requires Python package 'pyenchant'." "$LAST_LOG"; then
    :
else
    fail_with_log "unexpected pack rule output: expected dry-run command or pyenchant dependency message" "$LAST_LOG"
fi

echo "[smoke] self-test mode runs to completion"
run_case self_test bash -lc "./hash-cracker.sh --self-test --dry-run"
if [ "$LAST_RC" -ne 0 ] && [ "$LAST_RC" -ne 1 ]; then
    echo "[FAIL] expected self-test rc to be 0 or 1, got rc=$LAST_RC"
    cat "$LAST_LOG"
    exit 1
fi
assert_contains "Self-test: configuration and dependency checks"
if ! grep -Eq "Self-test (passed|failed)" "$LAST_LOG"; then
    echo "[FAIL] expected self-test summary line"
    cat "$LAST_LOG"
    exit 1
fi

echo "[smoke] ctrl+c during a running job does not trigger menu spin"
CTRL_LOG="$TMP_DIR/ctrlc.log"
CTRL_FIFO="$TMP_DIR/ctrlc.in"
FAKE_PID_FILE="$TMP_DIR/fake-hashcat.pid"
FAKE_HASHCAT="$TMP_DIR/fake-hashcat.sh"

cat >"$FAKE_HASHCAT" <<EOF
#!/usr/bin/env bash
trap 'exit 130' INT TERM
printf '%s' "\$\$" > "$FAKE_PID_FILE"
sleep 30
EOF
chmod +x "$FAKE_HASHCAT"

cat >"$CONFIG_PATH" <<EOF
HASHCAT=($FAKE_HASHCAT)
DEVICE=1
HASHTYPE=1000
HASHLIST=input
POTFILE=hash-cracker.pot
WORDLIST=wordlists/ignis-1M.txt
WORDLIST2=wordlists/ignis-1K.txt
EOF

rm -f "$CTRL_FIFO" "$CTRL_LOG" "$FAKE_PID_FILE"
mkfifo "$CTRL_FIFO"

(
    ./hash-cracker.sh <"$CTRL_FIFO" >"$CTRL_LOG" 2>&1
) &
CTRL_MAIN_PID=$!

exec 3>"$CTRL_FIFO"
printf '4\nsmokectrlc\n' >&3

CTRL_STARTED=0
for _ in $(seq 1 80); do
    if [ -s "$FAKE_PID_FILE" ]; then
        CTRL_STARTED=1
        break
    fi
    sleep 0.05
done

if [ "$CTRL_STARTED" -ne 1 ]; then
    exec 3>&-
    kill -TERM "$CTRL_MAIN_PID" 2>/dev/null || true
    wait "$CTRL_MAIN_PID" 2>/dev/null || true
    fail_with_log "ctrl+c smoke setup failed (job did not start)" "$CTRL_LOG"
fi

CTRL_JOB_PID="$(cat "$FAKE_PID_FILE")"
kill -INT "$CTRL_JOB_PID" 2>/dev/null || true
kill -INT "$CTRL_MAIN_PID" 2>/dev/null || true
exec 3>&-

sleep 1
CTRL_MENU_COUNT="$(grep -c '^0\. Exit$' "$CTRL_LOG" || true)"
if [ "$CTRL_MENU_COUNT" -gt 3 ]; then
    kill -TERM "$CTRL_MAIN_PID" 2>/dev/null || true
    wait "$CTRL_MAIN_PID" 2>/dev/null || true
    fail_with_log "menu appears to spin after ctrl+c (0. Exit count: $CTRL_MENU_COUNT)" "$CTRL_LOG"
fi

kill -TERM "$CTRL_MAIN_PID" 2>/dev/null || true
wait "$CTRL_MAIN_PID" 2>/dev/null || true

restore_config

echo "[smoke] all smoke tests passed"
