#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

TMP_DIR="$(mktemp -d /tmp/hash-cracker-smoke.XXXX)"
CONFIG_PATH="$TMP_DIR/hash-cracker.conf"
export HASH_CRACKER_CONFIG="$CONFIG_PATH"
export SESSION_LOG_DIR="$TMP_DIR/logs"
export COMMON_SUBSTR_BIN="$TMP_DIR/common-substr.sh"
export CEWL="$TMP_DIR/cewl"

cat >"$COMMON_SUBSTR_BIN" <<'EOF'
#!/usr/bin/env bash
printf 'preview\n'
EOF
chmod +x "$COMMON_SUBSTR_BIN"

cat >"$CEWL" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$CEWL"

printf 'hash:password\n' >"$TMP_DIR/input"
: >"$TMP_DIR/hash-cracker.pot"
printf 'password\n' >"$TMP_DIR/wordlist.txt"
printf 'test\n' >"$TMP_DIR/wordlist2.txt"

cat >"$CONFIG_PATH" <<EOF
HASHCAT=($TMP_DIR/fake-hashcat)
DEVICE=1
HASHTYPE=1000
HASHLIST=$TMP_DIR/input
POTFILE=$TMP_DIR/hash-cracker.pot
WORDLIST=$TMP_DIR/wordlist.txt
WORDLIST2=$TMP_DIR/wordlist2.txt
EOF

cat >"$TMP_DIR/fake-hashcat" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMP_DIR/fake-hashcat"

TTY_TRACE_ENV="$TMP_DIR/tty-trace-env"
cat >"$TTY_TRACE_ENV" <<'EOF'
unset BASH_XTRACEFD
exec 2>>"${HASH_CRACKER_TRACE_FILE:-/dev/null}"
PS4='+${BASH_SOURCE[0]}:${LINENO}: '
export PS4
set -x
EOF

EDGE_AWK_BIN="$TMP_DIR/edge-awk-bin"
mkdir -p "$EDGE_AWK_BIN"
REAL_AWK="$(command -v awk)"
cat >"$EDGE_AWK_BIN/awk" <<EOF
#!/usr/bin/env bash
for argument do
    if [ "\$argument" = 'scripts/extensions/hashtypes' ]; then
        printf '1000 1000\\n'
        exit 0
    fi
done
exec '$REAL_AWK' "\$@"
EOF
chmod +x "$EDGE_AWK_BIN/awk"

restore_config() {
    return 0
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

echo "[smoke] campaign execution failure controls are explicit"
CAMPAIGN_MISSING_PATH="$TMP_DIR/missing-campaign.json"
run_case campaign_missing_manifest bash -lc "./hash-cracker.sh --execute '$CAMPAIGN_MISSING_PATH'"
assert_rc_eq 1
assert_contains "Campaign manifest not found: $CAMPAIGN_MISSING_PATH"

fail_with_log() {
    local message="$1"
    local log_file="$2"
    echo "[FAIL] $message"
    [ -f "$log_file" ] && cat "$log_file"
    exit 1
}

echo "[smoke] sourceable helpers cover defensive branches"
run_case helper_negative_duration bash -lc 'source ./hash-cracker.sh; [ "$(format_duration -1)" = "00:00:00" ]'
assert_rc_eq 0

HELPER_POTFILE="$TMP_DIR/helper-potfile"
printf 'hash:first\nhash:second\nhash:first\n' >"$HELPER_POTFILE"
run_case helper_potfile_counts bash -lc "source ./hash-cracker.sh; POTFILE='$HELPER_POTFILE'; [ \"\$(count_potfile_unique_plaintexts)\" = 2 ] && POTFILE='$TMP_DIR/missing-helper-potfile' && [ \"\$(count_potfile_unique_plaintexts)\" = 0 ]"
assert_rc_eq 0

HELPER_PRUNE_DIR="$TMP_DIR/helper-prune"
mkdir -p "$HELPER_PRUNE_DIR"
touch "$HELPER_PRUNE_DIR/session-20200101-000000-1.log"
run_case helper_prune_branches bash -lc "source ./hash-cracker.sh; prune_session_logs '$HELPER_PRUNE_DIR' invalid; prune_session_logs '$HELPER_PRUNE_DIR' 5"
assert_rc_eq 0

run_case helper_invalid_processor bash -lc 'source ./hash-cracker.sh; if run_processor 999; then exit 1; else exit 0; fi'
assert_rc_eq 0

run_case helper_invalid_processor_path bash -lc 'source ./hash-cracker.sh; if processor_path_by_id 999; then exit 1; else exit 0; fi'
assert_rc_eq 0

run_case helper_unsupported_preset bash -lc 'source ./hash-cracker.sh; preset_entries() { printf "invalid|Invalid fixture|2\\n"; }; if run_preset_mode invalid; then exit 1; else exit 0; fi'
assert_rc_eq 0

run_case helper_unknown_preset_job bash -lc 'source ./hash-cracker.sh; preset_entries() { printf "invalid|Invalid fixture|999\\n"; }; preset_job_supported() { return 0; }; if run_preset_mode invalid; then exit 1; else exit 0; fi'
assert_rc_eq 0

run_case helper_dynamic_bootstrap bash -lc "source ./hash-cracker.sh; STATICCONFIG=false; printf '1000\\n$TMP_DIR/input\\n' | processor_bootstrap"
assert_rc_eq 0

HELPER_INTERRUPT_FILE="$TMP_DIR/helper-interrupt"
printf 'temporary\n' >"$HELPER_INTERRUPT_FILE"
run_case helper_interrupt bash -lc "source ./hash-cracker.sh; processor_interrupt '$HELPER_INTERRUPT_FILE'"
assert_rc_eq 0
if [ -e "$HELPER_INTERRUPT_FILE" ]; then
    fail_with_log "processor interrupt did not clean its temporary file" "$LAST_LOG"
fi

HELPER_CAMPAIGN_INTERRUPT_PROCESSOR="$TMP_DIR/helper-campaign-interrupt-processor.sh"
HELPER_CAMPAIGN_INTERRUPT_MARKER="$TMP_DIR/helper-campaign-interrupt.marker"
printf 'processor_interrupt\n' >"$HELPER_CAMPAIGN_INTERRUPT_PROCESSOR"
run_case helper_campaign_interrupt bash -lc "source '$REPO_ROOT/hash-cracker.sh'; menu_entries() { printf '1|Interrupt fixture|$HELPER_CAMPAIGN_INTERRUPT_PROCESSOR\\n'; }; CAMPAIGN_INTERRUPT_MARKER='$HELPER_CAMPAIGN_INTERRUPT_MARKER'; if run_processor 1; then exit 1; else test \"\$?\" -eq 130; fi"
assert_rc_eq 0
if [ ! -f "$HELPER_CAMPAIGN_INTERRUPT_MARKER" ]; then
    fail_with_log "campaign interrupt marker was not created" "$LAST_LOG"
fi

run_case helper_campaign_unknown_job bash -lc "source '$REPO_ROOT/hash-cracker.sh'; campaign_jobs_for_source() { printf '999'; }; if run_campaign_plan fixture '$TMP_DIR/unknown-job.json'; then exit 1; else exit 0; fi"
assert_rc_eq 0

run_case helper_campaign_dependency_failure bash -lc "source '$REPO_ROOT/hash-cracker.sh'; campaign_jobs_for_source() { printf '1'; }; check_job_dependencies() { return 1; }; if run_campaign_plan fixture '$TMP_DIR/dependency-failure.json'; then exit 1; else exit 0; fi"
assert_rc_eq 0

run_case helper_campaign_plan_failure bash -lc "source '$REPO_ROOT/hash-cracker.sh'; campaign_jobs_for_source() { printf '1'; }; check_job_dependencies() { return 0; }; run_processor() { return 1; }; if run_campaign_plan fixture '$TMP_DIR/plan-failure.json'; then exit 1; else exit 0; fi"
assert_rc_eq 0

HELPER_CACHE="$TMP_DIR/helper-cache"
run_case helper_hashlist_refresh bash -lc "source ./hash-cracker.sh; HASHLIST='$TMP_DIR/input'; POTFILE=/dev/null; SESSION_POT_UNIQUE_CACHE='$HELPER_CACHE'; SESSION_POT_LINES_LAST=0; SESSION_POT_BYTES_LAST=0; SESSION_POT_LINES_BASE=0; SESSION_POT_UNIQUE_BASE=0; SESSION_POT_BYTES_BASE=0; SESSION_POT_UNIQUE_CUR=0; SESSION_HASHLIST_PATH_LAST='$TMP_DIR/old-hashlist'; refresh_session_stats"
assert_rc_eq 0

run_case helper_missing_pack_files bash -lc "source '$REPO_ROOT/hash-cracker.sh'; cd '$TMP_DIR'; MACHINE=Linux; DRYRUN=' '; if check_job_dependencies 12; then exit 1; else exit 0; fi"
assert_rc_eq 0
run_case helper_missing_pack_mask_files bash -lc "source '$REPO_ROOT/hash-cracker.sh'; cd '$TMP_DIR'; MACHINE=Linux; DRYRUN=' '; if check_job_dependencies 13; then exit 1; else exit 0; fi"
assert_rc_eq 0

NO_PYTHON_PATH="$TMP_DIR/no-python-path"
mkdir -p "$NO_PYTHON_PATH"
run_case helper_missing_python_rulegen bash -lc "source '$REPO_ROOT/hash-cracker.sh'; MACHINE=Linux; DRYRUN=''; PATH='$NO_PYTHON_PATH'; if check_job_dependencies 12; then exit 1; else exit 0; fi"
assert_rc_eq 0
run_case helper_missing_python_maskgen bash -lc "source '$REPO_ROOT/hash-cracker.sh'; MACHINE=Linux; DRYRUN=''; PATH='$NO_PYTHON_PATH'; if check_job_dependencies 13; then exit 1; else exit 0; fi"
assert_rc_eq 0

run_case helper_self_test_hashcat_available bash -lc "source '$REPO_ROOT/hash-cracker.sh'; DRYRUN=''; HASHCAT_BIN=/bin/true; HASHLIST=/dev/null; WORDLIST=/dev/null; WORDLIST2=/dev/null; MACHINE=Linux; CEWL='$CEWL'; run_self_test >/dev/null 2>&1 || true"
assert_rc_eq 0
run_case helper_self_test_hashcat_missing bash -lc "source '$REPO_ROOT/hash-cracker.sh'; DRYRUN=''; HASHCAT_BIN='$TMP_DIR/missing-helper-hashcat'; HASHLIST=/dev/null; WORDLIST=/dev/null; WORDLIST2=/dev/null; MACHINE=Linux; CEWL='$CEWL'; run_self_test >/dev/null 2>&1 || true"
assert_rc_eq 0

run_case parameters_list_jobs_case bash -lc "source '$REPO_ROOT/hash-cracker.sh'; source '$REPO_ROOT/scripts/parameters.sh' --list-jobs"
assert_rc_eq 0
run_case parameters_list_presets_case bash -lc "source '$REPO_ROOT/hash-cracker.sh'; source '$REPO_ROOT/scripts/parameters.sh' --list-presets"
assert_rc_eq 0

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

echo "[smoke] color initialization works in a terminal"
run_case colors_tty env -u NO_COLOR BASH_ENV="$TTY_TRACE_ENV" TERM=xterm script -qec './hash-cracker.sh --dry-run --job 1' /dev/null
assert_rc_eq 0
assert_contains "Brute force processing done"

echo "[smoke] fresh-checkout configuration failures are clear"
run_case missing_config bash -lc "HASH_CRACKER_CONFIG='$TMP_DIR/missing.conf' ./hash-cracker.sh --dry-run"
assert_rc_eq 1
assert_contains "Missing required configuration file"

INCOMPLETE_CONFIG="$TMP_DIR/incomplete.conf"
printf 'HASHCAT=(%s)\n' "$TMP_DIR/fake-hashcat" >"$INCOMPLETE_CONFIG"
run_case incomplete_config bash -lc "HASH_CRACKER_CONFIG='$INCOMPLETE_CONFIG' ./hash-cracker.sh --dry-run"
assert_rc_eq 1
assert_contains "Missing required setting 'HASHTYPE'"

echo "[smoke] missing flag values fail before startup"
run_case missing_flag_value bash -lc "./hash-cracker.sh --stats-export"
assert_rc_eq 1
assert_contains "Missing value for --stats-export"

run_case campaign_missing_plan_value bash -lc "./hash-cracker.sh --plan"
assert_rc_eq 1
assert_contains "Missing value for --plan"

run_case campaign_missing_plan_equals_value bash -lc "./hash-cracker.sh --plan="
assert_rc_eq 1
assert_contains "Missing value for --plan"

run_case campaign_missing_plan_output bash -lc "./hash-cracker.sh --plan quick"
assert_rc_eq 1
assert_contains "Campaign plans require --output PATH."

run_case campaign_missing_output_value bash -lc "./hash-cracker.sh --output"
assert_rc_eq 1
assert_contains "Missing value for --output"

run_case campaign_missing_output_equals_value bash -lc "./hash-cracker.sh --output="
assert_rc_eq 1
assert_contains "Missing value for --output"

run_case campaign_missing_execute_value bash -lc "./hash-cracker.sh --execute"
assert_rc_eq 1
assert_contains "Missing value for --execute"

run_case campaign_missing_execute_equals_value bash -lc "./hash-cracker.sh --execute="
assert_rc_eq 1
assert_contains "Missing value for --execute"

run_case campaign_missing_resume_value bash -lc "./hash-cracker.sh --resume"
assert_rc_eq 1
assert_contains "Missing value for --resume"

run_case campaign_missing_resume_equals_value bash -lc "./hash-cracker.sh --resume="
assert_rc_eq 1
assert_contains "Missing value for --resume"

run_case campaign_output_without_plan bash -lc "./hash-cracker.sh --output campaign.json"
assert_rc_eq 1
assert_contains "--output is only valid with --plan"

run_case campaign_execute_resume_conflict bash -lc "./hash-cracker.sh --execute one.json --resume two.json"
assert_rc_eq 1
assert_contains "Use either --execute or --resume"

run_case campaign_plan_execute_conflict bash -lc "./hash-cracker.sh --plan quick --output plan.json --execute plan.json"
assert_rc_eq 1
assert_contains "Use either --plan or --execute/--resume"

run_case campaign_plan_job_conflict bash -lc "./hash-cracker.sh --plan quick --output plan.json --job 1"
assert_rc_eq 1
assert_contains "Use either --plan or --preset/--job"

run_case campaign_execute_job_conflict bash -lc "./hash-cracker.sh --execute plan.json --job 1"
assert_rc_eq 1
assert_contains "Use either --execute/--resume or --preset/--job"

run_case campaign_resume_preset_conflict bash -lc "./hash-cracker.sh --resume plan.json --preset quick"
assert_rc_eq 1
assert_contains "Use either --execute/--resume or --preset/--job"

run_case campaign_interactive_job bash -lc "./hash-cracker.sh --plan 2 --output '$TMP_DIR/interactive-campaign.json'"
assert_rc_eq 1
assert_contains "requires interactive input or is unsupported"

run_case campaign_invalid_preset bash -lc "./hash-cracker.sh --plan nope --output '$TMP_DIR/invalid-campaign.json'"
assert_rc_eq 1
assert_contains "Invalid campaign preset: nope"

echo "[smoke] early informational and CLI validation modes are deterministic"
run_case module_info bash -lc "./hash-cracker.sh --module-info"
assert_rc_eq 1
assert_contains "Information about the modules"
assert_contains "14. Fingerprint attack"

run_case search_hash_type bash -lc "./hash-cracker.sh --search ntlm"
assert_rc_eq 1
assert_contains "1000 | NTLM"

run_case search_missing_value bash -lc "./hash-cracker.sh --search"
assert_rc_eq 1
assert_contains "Please provide a search value"

run_case unknown_parameter bash -lc "./hash-cracker.sh --not-a-real-flag"
assert_rc_eq 1
assert_contains "Unknown parameter passed: --not-a-real-flag"

run_case invalid_job_value bash -lc "./hash-cracker.sh --dry-run --job nope"
assert_rc_eq 1
assert_contains "Invalid value for --job. Expected a numeric job ID."

run_case missing_job_value bash -lc "./hash-cracker.sh --dry-run --job"
assert_rc_eq 1
assert_contains "Invalid value for --job. Expected a numeric job ID."

run_case invalid_job_equals_value bash -lc "./hash-cracker.sh --dry-run --job=oops"
assert_rc_eq 1
assert_contains "Invalid value for --job. Expected a numeric job ID."

run_case missing_preset_value bash -lc "./hash-cracker.sh --dry-run --preset"
assert_rc_eq 1
assert_contains "Missing value for --preset. Provide a preset name."

run_case missing_stats_scope_value bash -lc "./hash-cracker.sh --dry-run --stats-export-scope"
assert_rc_eq 1
assert_contains "Invalid value for --stats-export-scope. Use 'latest' or 'all'."

run_case invalid_stats_scope_equals_value bash -lc "./hash-cracker.sh --dry-run --stats-export-scope=broken"
assert_rc_eq 1
assert_contains "Invalid value for --stats-export-scope. Use 'latest' or 'all'."

run_case invalid_session_log_keep bash -lc "./hash-cracker.sh --dry-run --session-log-keep nope"
assert_rc_eq 1
assert_contains "Invalid value for --session-log-keep. Expected a non-negative integer."

run_case invalid_session_log_keep_equals bash -lc "./hash-cracker.sh --dry-run --session-log-keep=-1"
assert_rc_eq 1
assert_contains "Invalid value for --session-log-keep. Expected a non-negative integer."

run_case short_help bash -lc "./hash-cracker.sh -h"
assert_rc_eq 1
assert_contains "Usage: ./hash-cracker.sh [FLAG]"

run_case short_module_info bash -lc "./hash-cracker.sh -m"
assert_rc_eq 1
assert_contains "Information about the modules"

run_case short_search bash -lc "./hash-cracker.sh -s ntlm"
assert_rc_eq 1
assert_contains "1000 | NTLM"

run_case doctor_alias bash -lc "./hash-cracker.sh --doctor --dry-run"
if [ "$LAST_RC" -ne 0 ] && [ "$LAST_RC" -ne 1 ]; then
    echo "[FAIL] expected --doctor rc to be 0 or 1, got rc=$LAST_RC"
    cat "$LAST_LOG"
    exit 1
fi
assert_contains "Self-test: configuration and dependency checks"

STATS_EXPORT_EQUALS_PATH="$TMP_DIR/stats-export-equals.json"
run_case stats_export_equals bash -lc "printf '0\n' | ./hash-cracker.sh --dry-run --stats-export='$STATS_EXPORT_EQUALS_PATH'"
assert_rc_eq 0
if [ ! -s "$STATS_EXPORT_EQUALS_PATH" ]; then
    fail_with_log "equals-form stats export file was not created" "$LAST_LOG"
fi

STATS_EXPORT_SCOPE_EQUALS_PATH="$TMP_DIR/stats-export-scope-equals.json"
run_case stats_export_scope_equals bash -lc "printf '0\n' | ./hash-cracker.sh --dry-run --stats-export='$STATS_EXPORT_SCOPE_EQUALS_PATH' --stats-export-scope=all"
assert_rc_eq 0
if ! grep -Fq '"export_scope": "all"' "$STATS_EXPORT_SCOPE_EQUALS_PATH"; then
    fail_with_log "equals-form stats export scope was not applied" "$STATS_EXPORT_SCOPE_EQUALS_PATH"
fi

run_case stats_export_equals_missing_value bash -lc "./hash-cracker.sh --dry-run --stats-export="
assert_rc_eq 1
assert_contains "Missing value for --stats-export. Provide a file path."

run_case preset_equals bash -lc "./hash-cracker.sh --dry-run --preset=quick"
assert_rc_eq 0
assert_contains "Running preset 'quick' (jobs: 1,9)"

run_case job_equals bash -lc "./hash-cracker.sh --dry-run --job=1"
assert_rc_eq 0
assert_contains "Job 1 (Brute force) completed in"

run_case session_log_keep_equals bash -lc "printf '0\n' | SESSION_LOG_DIR='$TMP_DIR/equals-retention-logs' ./hash-cracker.sh --dry-run --session-log-keep=1"
assert_rc_eq 0
assert_contains "Session log retention: keeping last 1 file(s)"

run_case preset_equals_missing_value bash -lc "./hash-cracker.sh --dry-run --preset="
assert_rc_eq 1
assert_contains "Missing value for --preset. Provide a preset name."

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

echo "[smoke] session logging controls are isolated and observable"
NO_LOG_EXPORT="$TMP_DIR/no-log-stats.json"
run_case no_session_log bash -lc "printf '0\n' | SESSION_LOG_DIR='$TMP_DIR/no-logs' ./hash-cracker.sh --dry-run --no-session-log --stats-export '$NO_LOG_EXPORT'"
assert_rc_eq 0
assert_not_contains "Session log file: logs/"
if ! grep -Fq '"enabled": false' "$NO_LOG_EXPORT"; then
    fail_with_log "stats export did not record disabled session logging" "$NO_LOG_EXPORT"
fi

RETENTION_LOG_DIR="$TMP_DIR/retention-logs"
mkdir -p "$RETENTION_LOG_DIR"
touch "$RETENTION_LOG_DIR/session-20200101-000000-1.log" "$RETENTION_LOG_DIR/session-20200102-000000-2.log"
run_case session_log_retention bash -lc "printf '0\n' | SESSION_LOG_DIR='$RETENTION_LOG_DIR' ./hash-cracker.sh --dry-run --session-log-keep 1"
assert_rc_eq 0
if [ "$(find "$RETENTION_LOG_DIR" -maxdepth 1 -type f -name 'session-*.log' | wc -l | tr -d '[:space:]')" -ne 1 ]; then
    fail_with_log "session log retention did not keep one log" "$LAST_LOG"
fi

run_case session_log_retention_zero bash -lc "printf '0\n' | ./hash-cracker.sh --dry-run --session-log-keep 0"
assert_rc_eq 0
assert_contains "Session log retention: keeping all files (pruning disabled)"

echo "[smoke] invalid stats export scope fails clearly"
run_case stats_export_scope_invalid bash -lc "./hash-cracker.sh --stats-export \"$TMP_DIR/invalid-scope.json\" --stats-export-scope nope"
assert_rc_eq 1
assert_contains "Invalid value for --stats-export-scope. Use 'latest' or 'all'."

echo "[smoke] missing runtime data files are handled without mutation in dry-run"
MISSING_POTFILE="$TMP_DIR/missing-potfile"
rm -f "$MISSING_POTFILE"
cat >"$CONFIG_PATH" <<EOF
HASHCAT=($TMP_DIR/fake-hashcat)
DEVICE=1
HASHTYPE=1000
HASHLIST=$TMP_DIR/input
POTFILE=$MISSING_POTFILE
WORDLIST=$TMP_DIR/wordlist.txt
WORDLIST2=$TMP_DIR/wordlist2.txt
EOF
run_case missing_potfile bash -lc "./hash-cracker.sh --dry-run --job 1"
assert_rc_eq 0
assert_contains "Potfile not present, dry-run would create $MISSING_POTFILE"
if [ -e "$MISSING_POTFILE" ]; then
    fail_with_log "dry-run unexpectedly created the missing potfile" "$LAST_LOG"
fi

MISSING_HASHLIST="$TMP_DIR/missing-hashlist"
MISSING_WORDLIST="$TMP_DIR/missing-wordlist"
cat >"$CONFIG_PATH" <<EOF
HASHCAT=($TMP_DIR/fake-hashcat)
DEVICE=1
HASHTYPE=1000
HASHLIST=$MISSING_HASHLIST
POTFILE=$TMP_DIR/hash-cracker.pot
WORDLIST=$MISSING_WORDLIST
WORDLIST2=$TMP_DIR/missing-wordlist2
EOF
run_case self_test_missing_paths bash -lc "./hash-cracker.sh --self-test --dry-run"
assert_rc_eq 1
assert_contains "HASHLIST missing: $MISSING_HASHLIST"
assert_contains "WORDLIST missing: $MISSING_WORDLIST"
assert_contains "WORDLIST2 missing: $TMP_DIR/missing-wordlist2"
assert_contains "Self-test failed"

cat >"$CONFIG_PATH" <<EOF
HASHCAT=($TMP_DIR/fake-hashcat)
DEVICE=1
HASHTYPE=1000
HASHLIST=$TMP_DIR/input
POTFILE=$TMP_DIR/hash-cracker.pot
WORDLIST=$TMP_DIR/wordlist.txt
WORDLIST2=$TMP_DIR/wordlist2.txt
EOF
printf 'hash:password\n' >"$TMP_DIR/hash-cracker.pot"

MISSING_HASHCAT="$TMP_DIR/missing-hashcat"
cat >"$CONFIG_PATH" <<EOF
HASHCAT=($MISSING_HASHCAT)
DEVICE=1
HASHTYPE=1000
HASHLIST=$TMP_DIR/input
POTFILE=$TMP_DIR/hash-cracker.pot
WORDLIST=$TMP_DIR/wordlist.txt
WORDLIST2=$TMP_DIR/wordlist2.txt
EOF
run_case normal_missing_hashcat bash -lc "./hash-cracker.sh --job 1"
assert_rc_eq 1
assert_contains "Hashcat is not available/executable"
assert_contains "Not all mandatory requirements are met"

NORMAL_MISSING_POTFILE="$TMP_DIR/normal-missing-potfile"
rm -f -- "$NORMAL_MISSING_POTFILE"
cat >"$CONFIG_PATH" <<EOF
HASHCAT=($TMP_DIR/fake-hashcat)
DEVICE=1
HASHTYPE=1000
HASHLIST=$TMP_DIR/input
POTFILE=$NORMAL_MISSING_POTFILE
WORDLIST=$TMP_DIR/wordlist.txt
WORDLIST2=$TMP_DIR/wordlist2.txt
EOF
run_case normal_missing_potfile bash -lc "./hash-cracker.sh --job 1"
assert_rc_eq 0
assert_contains "Potfile not present, will create $NORMAL_MISSING_POTFILE"
if [ ! -f "$NORMAL_MISSING_POTFILE" ]; then
    fail_with_log "normal execution did not create the missing potfile" "$LAST_LOG"
fi

cat >"$CONFIG_PATH" <<EOF
HASHCAT=($TMP_DIR/fake-hashcat)
DEVICE=1
HASHTYPE=999999
HASHLIST=$TMP_DIR/input
POTFILE=$TMP_DIR/hash-cracker.pot
WORDLIST=$TMP_DIR/wordlist.txt
WORDLIST2=$TMP_DIR/wordlist2.txt
EOF
run_case unknown_hashtype bash -lc "./hash-cracker.sh --dry-run --job 1"
assert_rc_eq 0
assert_contains "Hashtype: 999999"

cat >"$CONFIG_PATH" <<EOF
HASHCAT=($TMP_DIR/fake-hashcat)
DEVICE=1
HASHTYPE=1000
HASHLIST=$TMP_DIR/input
POTFILE=$TMP_DIR/hash-cracker.pot
WORDLIST=$TMP_DIR/wordlist.txt
WORDLIST2=$TMP_DIR/wordlist2.txt
EOF
run_case hashtype_display_fallback bash -lc "PATH='$EDGE_AWK_BIN:$PATH' ./hash-cracker.sh --dry-run --job 1"
assert_rc_eq 0
assert_contains "Hashtype: 1000 1000"

cat >"$CONFIG_PATH" <<EOF
HASHCAT=($TMP_DIR/fake-hashcat)
DEVICE=1
HASHTYPE=1000
HASHLIST=$TMP_DIR/input
POTFILE=$TMP_DIR/hash-cracker.pot
WORDLIST=$TMP_DIR/wordlist.txt
WORDLIST2=$TMP_DIR/wordlist2.txt
EOF

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

run_case environment_job_list bash -lc "JOBLIST=' ' ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "1. Brute force"

run_case environment_preset_list bash -lc "PRESETLIST=' ' ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "quick - Quick baseline and iteration coverage (jobs: 1,9)"

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

echo "[smoke] campaign planning captures reproducible command steps"
CAMPAIGN_PATH="$TMP_DIR/quick-campaign.json"
run_case campaign_plan bash -lc "./hash-cracker.sh --plan quick --output '$CAMPAIGN_PATH'"
assert_rc_eq 0
assert_contains "Campaign plan ready: $CAMPAIGN_PATH"
if ! python3 - "$CAMPAIGN_PATH" <<'PY'; then
import json
import sys

manifest = json.load(open(sys.argv[1], encoding="utf-8"))
assert manifest["schema_version"] == "1"
assert manifest["status"] == "planned"
assert manifest["campaign"]["jobs"] == [1, 9]
assert len(manifest["steps"]) == 2
assert all(step["commands"] for step in manifest["steps"])
assert manifest["inputs"]["potfile"]["mutable"] is True
PY
    fail_with_log "campaign plan manifest was invalid" "$LAST_LOG"
fi

CAMPAIGN_JOB_PATH="$TMP_DIR/job-campaign.json"
run_case campaign_plan_equals bash -lc "./hash-cracker.sh --plan=1 --output='$CAMPAIGN_JOB_PATH'"
assert_rc_eq 0
assert_contains "Campaign plan ready: $CAMPAIGN_JOB_PATH"

echo "[smoke] campaign execution records completed steps and supports resume"
run_case campaign_execute_equals bash -lc "SESSION_LOG_DIR='$TMP_DIR/campaign-logs' ./hash-cracker.sh --execute='$CAMPAIGN_PATH'"
assert_rc_eq 0
assert_contains "Campaign has no incomplete steps: $CAMPAIGN_PATH"
if ! python3 - "$CAMPAIGN_PATH" <<'PY'; then
import json
import sys

manifest = json.load(open(sys.argv[1], encoding="utf-8"))
assert manifest["status"] == "completed"
assert all(step["state"] == "completed" for step in manifest["steps"])
assert all(step["executed_commands"] for step in manifest["steps"])
PY
    fail_with_log "completed campaign state was invalid" "$LAST_LOG"
fi

run_case campaign_resume_equals bash -lc "SESSION_LOG_DIR='$TMP_DIR/campaign-logs' ./hash-cracker.sh --resume='$CAMPAIGN_PATH'"
assert_rc_eq 0
assert_contains "Campaign has no incomplete steps: $CAMPAIGN_PATH"

CAMPAIGN_FAIL_HASHCAT="$TMP_DIR/campaign-failing-hashcat"
printf '#!/usr/bin/env bash\nexit 7\n' >"$CAMPAIGN_FAIL_HASHCAT"
chmod +x "$CAMPAIGN_FAIL_HASHCAT"
CAMPAIGN_FAIL_CONFIG="$TMP_DIR/campaign-failing.conf"
cat >"$CAMPAIGN_FAIL_CONFIG" <<EOF
HASHCAT=($CAMPAIGN_FAIL_HASHCAT)
DEVICE=1
HASHTYPE=1000
HASHLIST=$TMP_DIR/input
POTFILE=$TMP_DIR/hash-cracker.pot
WORDLIST=$TMP_DIR/wordlist.txt
WORDLIST2=$TMP_DIR/wordlist2.txt
EOF
CAMPAIGN_FAIL_PATH="$TMP_DIR/failing-campaign.json"
run_case campaign_failure_plan bash -lc "HASH_CRACKER_CONFIG='$CAMPAIGN_FAIL_CONFIG' ./hash-cracker.sh --plan=quick --output '$CAMPAIGN_FAIL_PATH'"
assert_rc_eq 0
run_case campaign_execute_failure bash -lc "HASH_CRACKER_CONFIG='$CAMPAIGN_FAIL_CONFIG' SESSION_LOG_DIR='$TMP_DIR/failing-campaign-logs' ./hash-cracker.sh --execute '$CAMPAIGN_FAIL_PATH'"
assert_rc_eq 7
assert_contains "Campaign '$CAMPAIGN_FAIL_PATH' stopped at step-001-job-1 with rc=7."
if ! python3 - "$CAMPAIGN_FAIL_PATH" <<'PY'; then
import json
import sys

manifest = json.load(open(sys.argv[1], encoding="utf-8"))
assert manifest["status"] == "failed"
assert manifest["steps"][0]["state"] == "failed"
assert manifest["steps"][0]["exit_code"] == 7
PY
    fail_with_log "failed campaign state was invalid" "$LAST_LOG"
fi

printf '#!/usr/bin/env bash\nexit 0\n' >"$CAMPAIGN_FAIL_HASHCAT"
run_case campaign_resume_failure bash -lc "HASH_CRACKER_CONFIG='$CAMPAIGN_FAIL_CONFIG' SESSION_LOG_DIR='$TMP_DIR/failing-campaign-logs' ./hash-cracker.sh --resume '$CAMPAIGN_FAIL_PATH'"
assert_rc_eq 0
assert_contains "Campaign has no incomplete steps: $CAMPAIGN_FAIL_PATH"
if ! python3 - "$CAMPAIGN_FAIL_PATH" <<'PY'; then
import json
import sys

manifest = json.load(open(sys.argv[1], encoding="utf-8"))
assert manifest["status"] == "completed"
assert manifest["steps"][0]["state"] == "completed"
assert manifest["steps"][0]["attempts"] == 2
PY
    fail_with_log "resumed campaign state was invalid" "$LAST_LOG"
fi

printf 'changed\n' >"$TMP_DIR/wordlist2.txt"
run_case campaign_stale_input bash -lc "SESSION_LOG_DIR='$TMP_DIR/campaign-logs' ./hash-cracker.sh --resume '$CAMPAIGN_PATH'"
assert_rc_eq 1
assert_contains "campaign input changed for wordlist2"
printf 'test\n' >"$TMP_DIR/wordlist2.txt"

run_case campaign_runtime_drift bash -lc "SESSION_LOG_DIR='$TMP_DIR/campaign-logs' ./hash-cracker.sh --resume '$CAMPAIGN_PATH' --no-limit"
assert_rc_eq 1
assert_contains "campaign runtime changed for kernel"

CAMPAIGN_NEXT_FAILURE_BIN="$TMP_DIR/campaign-next-failure-bin"
mkdir -p "$CAMPAIGN_NEXT_FAILURE_BIN"
cat >"$CAMPAIGN_NEXT_FAILURE_BIN/python3" <<'EOF'
#!/usr/bin/env bash
case "${2:-}" in
    validate) exit 0 ;;
    next) exit 1 ;;
    *) exit 0 ;;
esac
EOF
chmod +x "$CAMPAIGN_NEXT_FAILURE_BIN/python3"
: >"$TMP_DIR/campaign-next-failure.json"
run_case campaign_next_failure bash -lc "PATH='$CAMPAIGN_NEXT_FAILURE_BIN:$PATH' ./hash-cracker.sh --execute '$TMP_DIR/campaign-next-failure.json'"
assert_rc_eq 1
assert_contains "Unable to read the next campaign step."

CAMPAIGN_MARK_RUNNING_FAILURE_BIN="$TMP_DIR/campaign-mark-running-failure-bin"
mkdir -p "$CAMPAIGN_MARK_RUNNING_FAILURE_BIN"
cat >"$CAMPAIGN_MARK_RUNNING_FAILURE_BIN/python3" <<'EOF'
#!/usr/bin/env bash
case "${2:-}" in
    validate) exit 0 ;;
    next) printf '0|step-001-job-1|1|Brute force\n' ;;
    mark-running) exit 1 ;;
    *) exit 0 ;;
esac
EOF
chmod +x "$CAMPAIGN_MARK_RUNNING_FAILURE_BIN/python3"
: >"$TMP_DIR/campaign-mark-running-failure.json"
run_case campaign_mark_running_failure bash -lc "PATH='$CAMPAIGN_MARK_RUNNING_FAILURE_BIN:$PATH' ./hash-cracker.sh --execute '$TMP_DIR/campaign-mark-running-failure.json'"
assert_rc_eq 1

CAMPAIGN_DEPENDENCY_FAILURE_BIN="$TMP_DIR/campaign-dependency-failure-bin"
mkdir -p "$CAMPAIGN_DEPENDENCY_FAILURE_BIN"
cat >"$CAMPAIGN_DEPENDENCY_FAILURE_BIN/python3" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = '-c' ]; then
    exit 1
fi
case "${2:-}" in
    validate) exit 0 ;;
    next) printf '0|step-001-job-12|12|PACK rule\n' ;;
    *) exit 0 ;;
esac
EOF
chmod +x "$CAMPAIGN_DEPENDENCY_FAILURE_BIN/python3"
: >"$TMP_DIR/campaign-dependency-failure.json"
run_case campaign_dependency_failure bash -lc "PATH='$CAMPAIGN_DEPENDENCY_FAILURE_BIN:$PATH' ./hash-cracker.sh --execute '$TMP_DIR/campaign-dependency-failure.json'"
assert_rc_eq 1
assert_contains "Campaign '$TMP_DIR/campaign-dependency-failure.json' stopped at step-001-job-12 with rc=1."

CAMPAIGN_UPDATE_FAILURE_BIN="$TMP_DIR/campaign-update-failure-bin"
mkdir -p "$CAMPAIGN_UPDATE_FAILURE_BIN"
cat >"$CAMPAIGN_UPDATE_FAILURE_BIN/python3" <<'EOF'
#!/usr/bin/env bash
case "${2:-}" in
    validate) exit 0 ;;
    next) printf '0|step-001-job-1|1|Brute force\n' ;;
    update) exit 1 ;;
    *) exit 0 ;;
esac
EOF
chmod +x "$CAMPAIGN_UPDATE_FAILURE_BIN/python3"
: >"$TMP_DIR/campaign-update-failure.json"
run_case campaign_update_failure bash -lc "PATH='$CAMPAIGN_UPDATE_FAILURE_BIN:$PATH' ./hash-cracker.sh --execute '$TMP_DIR/campaign-update-failure.json'"
assert_rc_eq 1

CAMPAIGN_INTERRUPT_HASHCAT="$TMP_DIR/campaign-interrupt-hashcat"
cat >"$CAMPAIGN_INTERRUPT_HASHCAT" <<'EOF'
#!/usr/bin/env bash
kill -INT "$PPID"
sleep 0.1
exit 0
EOF
chmod +x "$CAMPAIGN_INTERRUPT_HASHCAT"
CAMPAIGN_INTERRUPT_CONFIG="$TMP_DIR/campaign-interrupt.conf"
cat >"$CAMPAIGN_INTERRUPT_CONFIG" <<EOF
HASHCAT=($CAMPAIGN_INTERRUPT_HASHCAT)
DEVICE=1
HASHTYPE=1000
HASHLIST=$TMP_DIR/input
POTFILE=$TMP_DIR/hash-cracker.pot
WORDLIST=$TMP_DIR/wordlist.txt
WORDLIST2=$TMP_DIR/wordlist2.txt
EOF
CAMPAIGN_INTERRUPT_PATH="$TMP_DIR/interrupted-campaign.json"
run_case campaign_interrupt_plan bash -lc "HASH_CRACKER_CONFIG='$CAMPAIGN_INTERRUPT_CONFIG' ./hash-cracker.sh --plan 1 --output '$CAMPAIGN_INTERRUPT_PATH'"
assert_rc_eq 0
run_case campaign_interrupt_execute bash -lc "HASH_CRACKER_CONFIG='$CAMPAIGN_INTERRUPT_CONFIG' SESSION_LOG_DIR='$TMP_DIR/interrupted-campaign-logs' ./hash-cracker.sh --execute '$CAMPAIGN_INTERRUPT_PATH'"
assert_rc_eq 130
assert_contains "Campaign '$CAMPAIGN_INTERRUPT_PATH' stopped at step-001-job-1 with rc=130."
if ! python3 - "$CAMPAIGN_INTERRUPT_PATH" <<'PY'; then
import json
import sys

manifest = json.load(open(sys.argv[1], encoding="utf-8"))
assert manifest["status"] == "paused"
assert manifest["steps"][0]["state"] == "interrupted"
PY
    fail_with_log "interrupted campaign state was invalid" "$LAST_LOG"
fi

printf '#!/usr/bin/env bash\nexit 0\n' >"$CAMPAIGN_INTERRUPT_HASHCAT"
run_case campaign_interrupt_resume bash -lc "HASH_CRACKER_CONFIG='$CAMPAIGN_INTERRUPT_CONFIG' SESSION_LOG_DIR='$TMP_DIR/interrupted-campaign-logs' ./hash-cracker.sh --resume '$CAMPAIGN_INTERRUPT_PATH'"
assert_rc_eq 0
if ! python3 - "$CAMPAIGN_INTERRUPT_PATH" <<'PY'; then
import json
import sys

manifest = json.load(open(sys.argv[1], encoding="utf-8"))
assert manifest["status"] == "completed"
assert manifest["steps"][0]["state"] == "completed"
assert manifest["steps"][0]["attempts"] == 2
PY
    fail_with_log "resumed interrupted campaign state was invalid" "$LAST_LOG"
fi

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
if ! grep -Fq '"release": "v6.5.0 \"Coverage Gate\""' "$PRESET_STATS_EXPORT_PATH"; then
    fail_with_log "preset stats export missing v6.5.0 release marker" "$PRESET_STATS_EXPORT_PATH"
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

run_case stats_dashboard_single_job bash -lc "./hash-cracker.sh --dry-run --job 99"
assert_rc_eq 0
assert_contains "Session Stats Dashboard"

run_case stats_dashboard_without_logging bash -lc "printf '99\n0\n' | ./hash-cracker.sh --dry-run --no-session-log"
assert_rc_eq 0
assert_contains "Session logging"
assert_contains "disabled"

run_case blank_menu_input bash -lc "printf '\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Bye..."

CUSTOM_SESSION_LOG="$TMP_DIR/custom-session/logs/session.log"
run_case custom_session_log bash -lc "printf '0\n' | SESSION_STATS_LOGFILE='$CUSTOM_SESSION_LOG' ./hash-cracker.sh --dry-run"
assert_rc_eq 0
if [ ! -s "$CUSTOM_SESSION_LOG" ]; then
    fail_with_log "custom session log was not created" "$LAST_LOG"
fi

rm -f -- "$TMP_DIR/relative-session.log"
run_case relative_session_log bash -lc "printf '0\n' | SESSION_STATS_LOGFILE='relative-session.log' ./hash-cracker.sh --dry-run"
assert_rc_eq 0
if [ ! -s "relative-session.log" ]; then
    fail_with_log "relative session log was not created" "$LAST_LOG"
fi
rm -f -- relative-session.log

FALLBACK_SCOPE_EXPORT="$TMP_DIR/fallback-scope.json"
run_case fallback_stats_scope bash -lc "printf '0\n' | STATSEXPORT_SCOPE=unexpected ./hash-cracker.sh --dry-run --stats-export '$FALLBACK_SCOPE_EXPORT'"
assert_rc_eq 0
if ! grep -Fq '"export_scope": "latest"' "$FALLBACK_SCOPE_EXPORT"; then
    fail_with_log "invalid environment stats scope did not fall back to latest" "$FALLBACK_SCOPE_EXPORT"
fi

EMPTY_HISTORY_EXPORT="$TMP_DIR/empty-history.json"
run_case missing_history_directory bash -lc "printf '0\n' | SESSION_LOG_DIR='$TMP_DIR/no-history-directory' ./hash-cracker.sh --dry-run --no-session-log --stats-export '$EMPTY_HISTORY_EXPORT' --stats-export-scope all"
assert_rc_eq 0
if ! grep -Fq '"history": []' "$EMPTY_HISTORY_EXPORT"; then
    fail_with_log "missing history directory did not export an empty history" "$EMPTY_HISTORY_EXPORT"
fi

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

echo "[smoke] all processors are reachable in dry-run mode"
run_case processor_2 bash -lc "printf '2\ns\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Default processing with light rules done"

run_case processor_3 bash -lc "printf '3\ns\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Default processing with heavy rules done"

run_case processor_4 bash -lc "printf '4\nAcme\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Word processing done"

run_case processor_5 bash -lc "printf '5\nAcme\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Word processing done"

run_case processor_6 bash -lc "printf '6\ns\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Hybrid processing done"

run_case processor_7 bash -lc "printf '7\ns\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Toggle processing done"

run_case processor_10 bash -lc "printf '10\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Prefix suffix processing done"

run_case processor_11 bash -lc "printf '11\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Substring processing done"

run_case processor_15 bash -lc "printf '15\n$TMP_DIR\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Multiple wordlists done"

run_case processor_16 bash -lc "./hash-cracker.sh --dry-run --job 16"
assert_rc_eq 0
assert_contains "Username as Password processing with rules done"

run_case processor_17 bash -lc "printf '17\nw\n1\n10\nn\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Markov-chain processing done"

run_case processor_18 bash -lc "printf '18\nhttps://example.test\n$TMP_DIR/cewl-list\n1\n4\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "CeWL created a wordlist named:"

run_case processor_20 bash -lc "printf '20\ns\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Stacking with light rules done"

run_case processor_21 bash -lc "printf '21\n2\nn\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Custom Brute Force Processing Done"

run_case processor_22 bash -lc "printf '22\n$TMP_DIR\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Multiple wordlists done"

echo "[smoke] multiple-wordlist mode reaches every mode-selecting processor"
run_case processor_2_multiple_mode bash -lc "printf '2\nm\n$TMP_DIR\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Default processing with light rules done"

run_case processor_3_multiple_mode bash -lc "printf '3\nm\n$TMP_DIR\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Default processing with heavy rules done"

run_case processor_6_multiple_mode bash -lc "printf '6\nm\n$TMP_DIR\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Hybrid processing done"

run_case processor_7_multiple_mode bash -lc "printf '7\nm\n$TMP_DIR\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Toggle processing done"

run_case processor_20_multiple_mode bash -lc "printf '20\nm\n$TMP_DIR\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Stacking with light rules done"

echo "[smoke] processor input validation and alternate paths are exercised"
cat >"$CONFIG_PATH" <<EOF
HASHCAT=($TMP_DIR/fake-hashcat)
DEVICE=1
HASHTYPE=1000
HASHLIST=$TMP_DIR/input
POTFILE=$TMP_DIR/hash-cracker.pot
WORDLIST=$TMP_DIR/wordlist.txt
WORDLIST2=$TMP_DIR/wordlist2.txt
FINGERPRINT_SEGMENT_MAX=0
EOF
run_case processor_14_invalid_config bash -lc "printf '14\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Invalid FINGERPRINT_SEGMENT_MAX: 0"
assert_contains "Not valid, try again"

cat >"$CONFIG_PATH" <<EOF
HASHCAT=($TMP_DIR/fake-hashcat)
DEVICE=1
HASHTYPE=1000
HASHLIST=$TMP_DIR/input
POTFILE=$TMP_DIR/hash-cracker.pot
WORDLIST=$TMP_DIR/wordlist.txt
WORDLIST2=$TMP_DIR/wordlist2.txt
EOF
run_case processor_17_invalid_source bash -lc "printf '17\nx\np\n1\n10\nn\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Try again"
assert_contains "Markov-chain processing done"

run_case processor_17_rules bash -lc "printf '17\np\n1\n10\ny\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Markov-chain processing done"

run_case processor_17_invalid_rules_choice bash -lc "printf '17\np\n1\n1\nx\np\n1\n1\nn\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Try again"
assert_contains "Markov-chain processing done"

run_case processor_18_invalid_ranges bash -lc "printf '18\nhttps://example.test\n$TMP_DIR/cewl-invalid-list\nx\n1\n0\n4\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Please only use 0-99."
assert_contains "Please only use 1-99."

run_case processor_21_invalid_number bash -lc "printf '21\nx\n2\nn\nn\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "is not a number."
assert_contains "Custom Brute Force Processing Done"

run_case processor_21_invalid_increment bash -lc "printf '21\n2\nx\n2\nn\nn\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Custom Brute Force Processing Done"

run_case processor_21_zero_length bash -lc "printf '21\n0\n2\nn\nn\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "NO!"
assert_contains "Custom Brute Force Processing Done"

run_case processor_21_increment bash -lc "printf '21\n2\ny\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "--increment"

echo "[smoke] dynamic selectors validate and accept interactive input"
run_case selector_hashtype bash -lc "printf '1000\n' | bash -c 'STATICCONFIG=false; source scripts/selectors/hashtype.sh'"
assert_rc_eq 0
assert_contains "Hashtype"
assert_contains "1000"

run_case selector_hashtype_invalid_format bash -lc "printf 'not-a-number\n1000\n' | bash -c 'STATICCONFIG=false; source scripts/selectors/hashtype.sh'"
assert_rc_eq 0
assert_contains "Not a valid hashtype number"
assert_contains "Hashtype"

run_case selector_hashtype_invalid_value bash -lc "printf '999999\n1000\n' | bash -c 'STATICCONFIG=false; source scripts/selectors/hashtype.sh'"
assert_rc_eq 0
assert_contains "Not a valid hashtype number"
assert_contains "Hashtype"

run_case selector_hashlist bash -lc "printf '$TMP_DIR/input\n' | bash -c 'STATICCONFIG=false; source scripts/selectors/hashlist.sh'"
assert_rc_eq 0
assert_contains "Hashlist $TMP_DIR/input selected."

run_case selector_hashlist_invalid bash -lc "printf '$TMP_DIR/no-input\n$TMP_DIR/input\n' | bash -c 'STATICCONFIG=false; source scripts/selectors/hashlist.sh'"
assert_rc_eq 0
assert_contains "File does not exist, try again."
assert_contains "Hashlist $TMP_DIR/input selected."

run_case selector_wordlist bash -lc "printf '$TMP_DIR/wordlist.txt\n' | bash -c 'STATICCONFIG=false; source scripts/selectors/wordlist.sh'"
assert_rc_eq 0
assert_contains "Wordlist $TMP_DIR/wordlist.txt selected."

run_case selector_wordlist_invalid bash -lc "printf '$TMP_DIR/no-wordlist\n$TMP_DIR/wordlist.txt\n' | bash -c 'STATICCONFIG=false; source scripts/selectors/wordlist.sh'"
assert_rc_eq 0
assert_contains "File does not exist, try again."
assert_contains "Wordlist $TMP_DIR/wordlist.txt selected."

run_case selector_multiple_wordlist_directory bash -lc "printf '$TMP_DIR\n' | bash -c 'START=15; STATICCONFIG=false; source scripts/selectors/multiple-wordlist.sh'"
assert_rc_eq 0
assert_contains "Directory $TMP_DIR selected."

run_case selector_multiple_wordlist_invalid_directory bash -lc "printf '$TMP_DIR/not-a-directory\n$TMP_DIR\n' | bash -c 'START=15; STATICCONFIG=false; source scripts/selectors/multiple-wordlist.sh'"
assert_rc_eq 0
assert_contains "Input must be a non-empty directory or an existing file, try again."
assert_contains "Directory $TMP_DIR selected."

run_case selector_multiple_wordlist_dynamic bash -lc "printf '$TMP_DIR/wordlist.txt\n$TMP_DIR/wordlist2.txt\n' | bash -c 'START=8; STATICCONFIG=false; source scripts/selectors/multiple-wordlist.sh'"
assert_rc_eq 0
assert_contains "Wordlist $TMP_DIR/wordlist.txt selected."
assert_contains "Wordlist $TMP_DIR/wordlist2.txt selected."

run_case selector_multiple_wordlist_file bash -lc "printf '$TMP_DIR/wordlist.txt\n' | bash -c 'START=15; STATICCONFIG=false; source scripts/selectors/multiple-wordlist.sh'"
assert_rc_eq 0
assert_contains "Wordlist file $TMP_DIR/wordlist.txt selected."

run_case selector_multiple_wordlist_first_invalid bash -lc "printf '$TMP_DIR/not-a-wordlist\n$TMP_DIR/wordlist.txt\n$TMP_DIR/wordlist2.txt\n$TMP_DIR/wordlist2.txt\n' | bash -c 'START=8; STATICCONFIG=false; source scripts/selectors/multiple-wordlist.sh'"
assert_rc_eq 0
assert_contains "File does not exist, try again."
assert_contains "Wordlist $TMP_DIR/wordlist2.txt selected."

run_case selector_multiple_wordlist_second_invalid bash -lc "printf '$TMP_DIR/wordlist.txt\n$TMP_DIR/not-a-wordlist\n$TMP_DIR/wordlist.txt\n$TMP_DIR/wordlist2.txt\n' | bash -c 'START=8; STATICCONFIG=false; source scripts/selectors/multiple-wordlist.sh'"
assert_rc_eq 0
assert_contains "File does not exist, try again."
assert_contains "Wordlist $TMP_DIR/wordlist2.txt selected."

MISSING_STATIC_WORDLIST="$TMP_DIR/missing-static-wordlist"
cat >"$CONFIG_PATH" <<EOF
HASHCAT=($TMP_DIR/fake-hashcat)
DEVICE=1
HASHTYPE=1000
HASHLIST=$TMP_DIR/input
POTFILE=$TMP_DIR/hash-cracker.pot
WORDLIST=$MISSING_STATIC_WORDLIST
WORDLIST2=$TMP_DIR/wordlist2.txt
EOF
run_case selector_static_wordlist_missing bash -lc "printf '2\ns\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Wordlist 1 does not exist, edit static configuration"

MISSING_STATIC_WORDLIST2="$TMP_DIR/missing-static-wordlist2"
cat >"$CONFIG_PATH" <<EOF
HASHCAT=($TMP_DIR/fake-hashcat)
DEVICE=1
HASHTYPE=1000
HASHLIST=$TMP_DIR/input
POTFILE=$TMP_DIR/hash-cracker.pot
WORDLIST=$TMP_DIR/wordlist.txt
WORDLIST2=$MISSING_STATIC_WORDLIST2
EOF
run_case selector_static_multiple_wordlist_missing bash -lc "printf '8\n0\n' | ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Wordlist 1 and/or 2 does not exist, edit static configuration"

cat >"$CONFIG_PATH" <<EOF
HASHCAT=($TMP_DIR/fake-hashcat)
DEVICE=1
HASHTYPE=1000
HASHLIST=$TMP_DIR/input
POTFILE=$TMP_DIR/hash-cracker.pot
WORDLIST=$TMP_DIR/wordlist.txt
WORDLIST2=$TMP_DIR/wordlist2.txt
EOF

echo "[smoke] CLI flag combinations reach resolved hashcat commands"
run_case flag_combinations bash -lc "printf '1\n0\n' | ./hash-cracker.sh --dry-run --no-limit --no-loopback --hwmon-enable --disable-cracked"
assert_rc_eq 0
assert_contains "Optimised kernels disabled"
assert_contains "Loopback disabled"
assert_contains "Hardware monitoring enabled"
assert_contains "STDOUT cracked hashes disabled"

echo "[smoke] Linux and macOS dependency selectors cover fallback paths"
PLATFORM_BIN="$TMP_DIR/platform-bin"
UNKNOWN_PLATFORM_BIN="$TMP_DIR/unknown-platform-bin"
mkdir -p "$PLATFORM_BIN" "$UNKNOWN_PLATFORM_BIN"

cat >"$PLATFORM_BIN/cewl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$PLATFORM_BIN/cewl"

run_case linux_cewl_path env CEWL= PATH="$PLATFORM_BIN:/usr/bin:/bin" /bin/bash -c 'source scripts/linux.sh; printf "%s\n" "$CEWL"'
assert_rc_eq 0
assert_contains "$PLATFORM_BIN/cewl"

run_case linux_cewl_missing env CEWL= PATH="$TMP_DIR/no-command-path" /bin/bash -c 'source scripts/linux.sh; test -z "$CEWL"'
assert_rc_eq 0

run_case mac_cewl_path env CEWL= PATH="$PLATFORM_BIN:/usr/bin:/bin" /bin/bash -c 'source scripts/mac.sh; printf "%s\n" "$CEWL"'
assert_rc_eq 0
assert_contains "$PLATFORM_BIN/cewl"

run_case mac_cewl_missing env CEWL= PATH="$TMP_DIR/no-command-path" /bin/bash -c 'source scripts/mac.sh; test -z "$CEWL"'
assert_rc_eq 0

MAC_BUNDLED_ROOT="$TMP_DIR/mac-bundled-root"
mkdir -p "$MAC_BUNDLED_ROOT/scripts/extensions/cewl"
cat >"$MAC_BUNDLED_ROOT/scripts/extensions/cewl/cewl.rb" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$MAC_BUNDLED_ROOT/scripts/extensions/cewl/cewl.rb"
run_case mac_bundled_cewl env CEWL= PATH="$TMP_DIR/no-command-path" /bin/bash -c "cd '$MAC_BUNDLED_ROOT' && source '$REPO_ROOT/scripts/mac.sh' && printf '%s\n' \"\$CEWL\""
assert_rc_eq 0
assert_contains "scripts/extensions/cewl/cewl.rb"

cat >"$PLATFORM_BIN/uname" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = '-s' ]; then
    printf 'Darwin\n'
else
    /usr/bin/uname "$@"
fi
EOF
chmod +x "$PLATFORM_BIN/uname"

run_case mac_job_10 bash -lc "PATH='$PLATFORM_BIN:$PATH' ./hash-cracker.sh --dry-run --job 10"
assert_rc_eq 0
assert_contains "common-substr-mac prefix/suffix"

run_case mac_job_11 bash -lc "PATH='$PLATFORM_BIN:$PATH' ./hash-cracker.sh --dry-run --job 11"
assert_rc_eq 0
assert_contains "common-substr-mac generation"

run_case mac_job_10_normal bash -lc "PATH='$PLATFORM_BIN:$PATH' COMMON_SUBSTR_BIN='$COMMON_SUBSTR_BIN' ./hash-cracker.sh --job 10"
assert_rc_eq 0
assert_contains "Prefix suffix processing done"

run_case mac_job_11_normal bash -lc "PATH='$PLATFORM_BIN:$PATH' COMMON_SUBSTR_BIN='$COMMON_SUBSTR_BIN' ./hash-cracker.sh --job 11"
assert_rc_eq 0
assert_contains "Substring processing done"

run_case mac_job_12 bash -lc "PATH='$PLATFORM_BIN:$PATH' ./hash-cracker.sh --dry-run --job 12"
assert_rc_eq 0
assert_contains "pack-mac/rulegen.py"

run_case mac_job_13 bash -lc "PATH='$PLATFORM_BIN:$PATH' ./hash-cracker.sh --dry-run --job 13"
assert_rc_eq 0
assert_contains "statsgen/maskgen"

run_case mac_job_17 bash -lc "printf '17\nw\n1\n10\nn\n0\n' | PATH='$PLATFORM_BIN:$PATH' ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "mkpass-mac"

FAKE_MKPASS="$TMP_DIR/fake-mkpass"
cat >"$FAKE_MKPASS" <<'EOF'
#!/usr/bin/env bash
printf 'generated\n'
EOF
chmod +x "$FAKE_MKPASS"
run_case mac_job_17_normal bash -lc "printf '17\\np\\n1\\n1\\ny\\n0\\n' | PATH='$PLATFORM_BIN:$PATH' MKPASS_BIN='$FAKE_MKPASS' ./hash-cracker.sh"
assert_rc_eq 0
assert_contains "Markov-chain processing done"

cat >"$UNKNOWN_PLATFORM_BIN/uname" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = '-s' ]; then
    printf 'Plan9\n'
else
    /usr/bin/uname "$@"
fi
EOF
chmod +x "$UNKNOWN_PLATFORM_BIN/uname"
run_case unknown_machine bash -lc "PATH='$UNKNOWN_PLATFORM_BIN:$PATH' ./hash-cracker.sh --dry-run --job 1"
assert_rc_eq 0
assert_contains "PLEASE OPEN ISSUE with output of 'uname -s'. Fallback to Linux"

MENU_MISSING_COMMON_SUBSTR="$TMP_DIR/menu-missing-common-substr"
run_case menu_dependency_failure bash -lc "printf '10\n0\n' | COMMON_SUBSTR_BIN='$MENU_MISSING_COMMON_SUBSTR' ./hash-cracker.sh --dry-run"
assert_rc_eq 0
assert_contains "Option 10 requires"
assert_contains "Bye..."

echo "[smoke] normal execution uses the fake hashcat and optional helpers"
run_case processor_10_normal bash -lc "./hash-cracker.sh --job 10"
assert_rc_eq 0
assert_contains "Prefix suffix processing done"

run_case processor_11_normal bash -lc "./hash-cracker.sh --job 11"
assert_rc_eq 0
assert_contains "Substring processing done"

run_case processor_9_normal bash -lc "./hash-cracker.sh --job 9"
assert_rc_eq 0
assert_contains "Iteration processing done"

run_case processor_14_normal bash -lc "./hash-cracker.sh --job 14"
assert_rc_eq 0
assert_contains "Fingerprint attack done"

run_case processor_17_normal bash -lc "printf '17\np\n1\n1\nn\n0\n' | ./hash-cracker.sh"
assert_rc_eq 0
assert_contains "Markov-chain processing done"

run_case processor_4_normal bash -lc "printf '4\nAcme\n0\n' | ./hash-cracker.sh"
assert_rc_eq 0
assert_contains "Word processing done"

run_case processor_5_normal bash -lc "printf '5\nAcme\n0\n' | ./hash-cracker.sh"
assert_rc_eq 0
assert_contains "Word processing done"

NORMAL_BIN="$TMP_DIR/normal-bin"
mkdir -p "$NORMAL_BIN"
cat >"$NORMAL_BIN/python3" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = '-c' ]; then
    exit 0
fi

previous=''
for argument do
    if [ "$previous" = '-o' ]; then
        : >"$argument"
    fi
    previous="$argument"
done

case "${1:-}" in
    *rulegen.py) : >analysis.rule ;;
esac
EOF
chmod +x "$NORMAL_BIN/python3"

NO_ENCHANT_BIN="$TMP_DIR/no-enchant-bin"
mkdir -p "$NO_ENCHANT_BIN"
cat >"$NO_ENCHANT_BIN/python3" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = '-c' ]; then
    exit 1
fi
exit 0
EOF
chmod +x "$NO_ENCHANT_BIN/python3"
run_case pack_rule_missing_enchant bash -lc "PATH='$NO_ENCHANT_BIN:$PATH' ./hash-cracker.sh --job 12"
assert_rc_eq 1
assert_contains "Option 12 requires Python package 'pyenchant'."

run_case mac_job_12_normal bash -lc "PATH='$PLATFORM_BIN:$NORMAL_BIN:$PATH' ./hash-cracker.sh --job 12"
assert_rc_eq 0
assert_contains "PACK rule processing done"

run_case mac_job_13_normal bash -lc "PATH='$PLATFORM_BIN:$NORMAL_BIN:$PATH' ./hash-cracker.sh --job 13"
assert_rc_eq 0
assert_contains "PACK mask processing done"

run_case processor_12_normal bash -lc "printf '12\n0\n' | PATH='$NORMAL_BIN:$PATH' ./hash-cracker.sh"
assert_rc_eq 0
assert_contains "PACK rule processing done"

run_case processor_13_normal bash -lc "printf '13\n0\n' | PATH='$NORMAL_BIN:$PATH' ./hash-cracker.sh"
assert_rc_eq 0
assert_contains "PACK mask processing done"

NORMAL_CEWL="$TMP_DIR/normal-cewl"
cat >"$NORMAL_CEWL" <<EOF
#!/usr/bin/env bash
output=''
previous=''
for argument do
    if [ "\$previous" = '-w' ]; then
        output="\$argument"
    fi
    previous="\$argument"
done
[ -z "\$output" ] || printf 'generated\n' >"\$output"
EOF
chmod +x "$NORMAL_CEWL"
run_case processor_18_normal bash -lc "printf '18\nhttps://example.test\n$TMP_DIR/normal-cewl-list\n1\n4\n0\n' | CEWL='$NORMAL_CEWL' ./hash-cracker.sh"
assert_rc_eq 0
assert_contains "CeWL created a wordlist named:"
if [ ! -s "$TMP_DIR/normal-cewl-list" ]; then
    fail_with_log "normal CeWL helper did not create its output" "$LAST_LOG"
fi

printf 'hash:pass123\nhash:\$HEX[616263313233]\n' >"$TMP_DIR/hash-cracker.pot"
run_case processor_19_normal bash -lc "./hash-cracker.sh --job 19"
assert_rc_eq 0
assert_contains "Digit removal / Hybrid processing done"

run_case processor_16_normal bash -lc "./hash-cracker.sh --job 16"
assert_rc_eq 0
assert_contains "Username as Password processing with rules done"

run_case processor_21_normal bash -lc "printf '21\n2\nn\n0\n' | ./hash-cracker.sh"
assert_rc_eq 0
assert_contains "Custom Brute Force Processing Done"

printf 'hash:password\n' >"$TMP_DIR/hash-cracker.pot"

echo "[smoke] session stats distinguish incremental updates from potfile rotation"
INCREMENTAL_HASHCAT="$TMP_DIR/incremental-hashcat"
cat >"$INCREMENTAL_HASHCAT" <<EOF
#!/usr/bin/env bash
printf 'hash:new-password\n' >>"$TMP_DIR/hash-cracker.pot"
EOF
chmod +x "$INCREMENTAL_HASHCAT"
cat >"$CONFIG_PATH" <<EOF
HASHCAT=($INCREMENTAL_HASHCAT)
DEVICE=1
HASHTYPE=1000
HASHLIST=$TMP_DIR/input
POTFILE=$TMP_DIR/hash-cracker.pot
WORDLIST=$TMP_DIR/wordlist.txt
WORDLIST2=$TMP_DIR/wordlist2.txt
EOF
run_case stats_incremental bash -lc "./hash-cracker.sh --stats-debug --job 1"
assert_rc_eq 0
assert_contains "Stats refresh mode: incremental"

DUPLICATE_HASHCAT="$TMP_DIR/duplicate-hashcat"
cat >"$DUPLICATE_HASHCAT" <<EOF
#!/usr/bin/env bash
printf 'hash:password\n' >>"$TMP_DIR/hash-cracker.pot"
EOF
chmod +x "$DUPLICATE_HASHCAT"
printf 'hash:password\n' >"$TMP_DIR/hash-cracker.pot"
cat >"$CONFIG_PATH" <<EOF
HASHCAT=($DUPLICATE_HASHCAT)
DEVICE=1
HASHTYPE=1000
HASHLIST=$TMP_DIR/input
POTFILE=$TMP_DIR/hash-cracker.pot
WORDLIST=$TMP_DIR/wordlist.txt
WORDLIST2=$TMP_DIR/wordlist2.txt
EOF
run_case stats_duplicate_plaintext bash -lc "./hash-cracker.sh --stats-debug --job 1"
assert_rc_eq 0
assert_contains "new unique plaintexts: 0"

EMPTY_DELTA_HASHCAT="$TMP_DIR/empty-delta-hashcat"
cat >"$EMPTY_DELTA_HASHCAT" <<EOF
#!/usr/bin/env bash
printf '\n' >>"$TMP_DIR/hash-cracker.pot"
EOF
chmod +x "$EMPTY_DELTA_HASHCAT"
printf 'hash:password\n' >"$TMP_DIR/hash-cracker.pot"
cat >"$CONFIG_PATH" <<EOF
HASHCAT=($EMPTY_DELTA_HASHCAT)
DEVICE=1
HASHTYPE=1000
HASHLIST=$TMP_DIR/input
POTFILE=$TMP_DIR/hash-cracker.pot
WORDLIST=$TMP_DIR/wordlist.txt
WORDLIST2=$TMP_DIR/wordlist2.txt
EOF
run_case stats_empty_delta bash -lc "./hash-cracker.sh --stats-debug --job 1"
assert_rc_eq 0
assert_contains "Stats refresh mode: full recount"

ZERO_LINE_DELTA_HASHCAT="$TMP_DIR/zero-line-delta-hashcat"
cat >"$ZERO_LINE_DELTA_HASHCAT" <<EOF
#!/usr/bin/env bash
printf 'suffix' >>"$TMP_DIR/hash-cracker.pot"
EOF
chmod +x "$ZERO_LINE_DELTA_HASHCAT"
printf 'hash:password\n' >"$TMP_DIR/hash-cracker.pot"
cat >"$CONFIG_PATH" <<EOF
HASHCAT=($ZERO_LINE_DELTA_HASHCAT)
DEVICE=1
HASHTYPE=1000
HASHLIST=$TMP_DIR/input
POTFILE=$TMP_DIR/hash-cracker.pot
WORDLIST=$TMP_DIR/wordlist.txt
WORDLIST2=$TMP_DIR/wordlist2.txt
EOF
run_case stats_zero_line_delta bash -lc "./hash-cracker.sh --stats-debug --job 1"
assert_rc_eq 0
assert_contains "Stats refresh mode: full recount"

NO_CACHE_HASHCAT="$TMP_DIR/no-cache-hashcat"
cat >"$NO_CACHE_HASHCAT" <<EOF
#!/usr/bin/env bash
rm -f -- /tmp/hash-cracker-unique-*.cache
printf 'hash:cache-rebuild\n' >>"$TMP_DIR/hash-cracker.pot"
EOF
chmod +x "$NO_CACHE_HASHCAT"
printf 'hash:password\n' >"$TMP_DIR/hash-cracker.pot"
cat >"$CONFIG_PATH" <<EOF
HASHCAT=($NO_CACHE_HASHCAT)
DEVICE=1
HASHTYPE=1000
HASHLIST=$TMP_DIR/input
POTFILE=$TMP_DIR/hash-cracker.pot
WORDLIST=$TMP_DIR/wordlist.txt
WORDLIST2=$TMP_DIR/wordlist2.txt
EOF
run_case stats_missing_cache bash -lc "./hash-cracker.sh --stats-debug --job 1"
assert_rc_eq 0
assert_contains "Stats refresh mode: incremental"

ROTATING_HASHCAT="$TMP_DIR/rotating-hashcat"
cat >"$ROTATING_HASHCAT" <<EOF
#!/usr/bin/env bash
: >"$TMP_DIR/hash-cracker.pot"
EOF
chmod +x "$ROTATING_HASHCAT"
printf 'hash:before-rotation\n' >"$TMP_DIR/hash-cracker.pot"
cat >"$CONFIG_PATH" <<EOF
HASHCAT=($ROTATING_HASHCAT)
DEVICE=1
HASHTYPE=1000
HASHLIST=$TMP_DIR/input
POTFILE=$TMP_DIR/hash-cracker.pot
WORDLIST=$TMP_DIR/wordlist.txt
WORDLIST2=$TMP_DIR/wordlist2.txt
EOF
run_case stats_rotated_potfile bash -lc "./hash-cracker.sh --stats-debug --job 1"
assert_rc_eq 0
assert_contains "Refreshing session stats (recounting unique potfile plaintexts"
assert_contains "Stats refresh mode: full recount"

printf 'hash:before-dashboard-rotation\n' >"$TMP_DIR/hash-cracker.pot"
run_case stats_rotation_dashboard bash -lc "printf '1\n99\n0\n' | ./hash-cracker.sh --stats-debug"
assert_rc_eq 0
assert_contains "Session Stats Dashboard"
assert_contains "Session delta"

cat >"$CONFIG_PATH" <<EOF
HASHCAT=($TMP_DIR/fake-hashcat)
DEVICE=1
HASHTYPE=1000
HASHLIST=$TMP_DIR/input
POTFILE=$TMP_DIR/hash-cracker.pot
WORDLIST=$TMP_DIR/wordlist.txt
WORDLIST2=$TMP_DIR/wordlist2.txt
EOF
printf 'hash:password\n' >"$TMP_DIR/hash-cracker.pot"

MALFORMED_LOG_DIR="$TMP_DIR/malformed-logs"
mkdir -p "$MALFORMED_LOG_DIR"
printf 'unbracketed history line\n[2020-01-01 00:00:00+0000] ordinary history line\n' \
    >"$MALFORMED_LOG_DIR/session-20200101-000000-1.log"
MALFORMED_EXPORT="$TMP_DIR/malformed-history.json"
run_case malformed_history_export bash -lc "printf '0\n' | SESSION_LOG_DIR='$MALFORMED_LOG_DIR' ./hash-cracker.sh --dry-run --no-session-log --stats-export '$MALFORMED_EXPORT' --stats-export-scope all"
assert_rc_eq 0
if ! grep -Fq 'unbracketed history line' "$MALFORMED_EXPORT"; then
    fail_with_log "stats export omitted malformed history entries" "$MALFORMED_EXPORT"
fi
if ! grep -Fq 'ordinary history line' "$MALFORMED_EXPORT"; then
    fail_with_log "stats export omitted rotated log entries" "$MALFORMED_EXPORT"
fi

echo "[smoke] dependency failure is reported by self-test"
MISSING_COMMON_SUBSTR="$TMP_DIR/missing-common-substr"
run_case self_test_dependency_failure bash -lc "COMMON_SUBSTR_BIN='$MISSING_COMMON_SUBSTR' ./hash-cracker.sh --self-test --dry-run"
if [ "$LAST_RC" -ne 0 ] && [ "$LAST_RC" -ne 1 ]; then
    echo "[FAIL] expected dependency self-test rc to be 0 or 1, got rc=$LAST_RC"
    cat "$LAST_LOG"
    exit 1
fi
assert_contains "Option 10 requires"
assert_contains "Self-test failed"

MISSING_CEWL="$TMP_DIR/missing-cewl"
run_case self_test_cewl_failure bash -lc "CEWL='$MISSING_CEWL' ./hash-cracker.sh --self-test --dry-run"
if [ "$LAST_RC" -ne 0 ] && [ "$LAST_RC" -ne 1 ]; then
    echo "[FAIL] expected CeWL dependency self-test rc to be 0 or 1, got rc=$LAST_RC"
    cat "$LAST_LOG"
    exit 1
fi
assert_contains "Option 18 requires CeWL executable"
assert_contains "Self-test failed"

MISSING_PRESET_COMMON="$TMP_DIR/missing-preset-common"
run_case preset_dependency_failure bash -lc "COMMON_SUBSTR_BIN='$MISSING_PRESET_COMMON' ./hash-cracker.sh --dry-run --preset quick-plus"
assert_rc_eq 1
assert_contains "Preset 'quick-plus' failed before job 11"
assert_contains "Preset 'quick-plus' summary"

echo "[smoke] preset stops and reports processor failure"
FAILING_HASHCAT="$TMP_DIR/failing-hashcat"
cat >"$FAILING_HASHCAT" <<'EOF'
#!/usr/bin/env bash
exit 7
EOF
chmod +x "$FAILING_HASHCAT"
cat >"$CONFIG_PATH" <<EOF
HASHCAT=($FAILING_HASHCAT)
DEVICE=1
HASHTYPE=1000
HASHLIST=$TMP_DIR/input
POTFILE=$TMP_DIR/hash-cracker.pot
WORDLIST=$TMP_DIR/wordlist.txt
WORDLIST2=$TMP_DIR/wordlist2.txt
EOF
run_case preset_failure bash -lc "./hash-cracker.sh --preset quick"
assert_rc_eq 7
assert_contains "Preset 'quick' failed at job 1"
assert_not_contains "Preset 'quick': running job 9"

run_case menu_processor_failure bash -lc "printf '1\n0\n' | ./hash-cracker.sh"
assert_rc_eq 0
assert_contains "Job 1 (Brute force) failed with rc=7"
assert_contains "Not valid, try again"

cat >"$CONFIG_PATH" <<EOF
HASHCAT=($TMP_DIR/fake-hashcat)
DEVICE=1
HASHTYPE=1000
HASHLIST=$TMP_DIR/input
POTFILE=$TMP_DIR/hash-cracker.pot
WORDLIST=$TMP_DIR/wordlist.txt
WORDLIST2=$TMP_DIR/wordlist2.txt
EOF

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
