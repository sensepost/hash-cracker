#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

function init_colors() {
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != "dumb" ]; then
        COLOR_RED=$'\033[31m'
        COLOR_GREEN=$'\033[1;32m'
        COLOR_CYAN=$'\033[36m'
        COLOR_RESET=$'\033[0m'
    else
        COLOR_RED=''
        COLOR_GREEN=''
        COLOR_CYAN=''
        COLOR_RESET=''
    fi
}

function status_ok() {
    printf '%b[+] %s%b\n' "$COLOR_GREEN" "$1" "$COLOR_RESET"
}

function status_bad() {
    printf '%b[-] %s%b\n' "$COLOR_RED" "$1" "$COLOR_RESET"
}

function status_error() {
    printf '%b[!] %s%b\n' "$COLOR_RED" "$1" "$COLOR_RESET"
}

function status_heading() {
    printf '%b%s%b\n' "$COLOR_CYAN" "$1" "$COLOR_RESET"
}

function banner_center_line() {
    local text="$1"
    local inner_width=91
    local clipped
    local text_len
    local total_pad
    local pad_left
    local pad_right

    clipped="${text:0:$inner_width}"
    text_len=${#clipped}
    total_pad=$((inner_width - text_len))
    pad_left=$((total_pad / 2))
    pad_right=$((total_pad - pad_left))

    printf '│ %*s%s%*s │\n' "$pad_left" '' "$clipped" "$pad_right" ''
}

function release_version_text() {
    printf '%s' 'v6.3 "Preset Rail"'
}

function release_label_text() {
    printf 'hash-cracker %s' "$(release_version_text)"
}

function hash-cracker() {
    local status_text
    local version_text
    local progress_text

    status_text="status: ${BANNER_STATUS:-cracking salted secrets}"
    version_text="$(release_version_text)"
    progress_text="[██████████████████░░░░] 82%"

    cat <<'EOF'

┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│ ██╗  ██╗ █████╗ ███████╗██╗  ██╗     ██████╗██████╗  █████╗  ██████╗██╗  ██╗███████╗██████╗ │
│ ██║  ██║██╔══██╗██╔════╝██║  ██║    ██╔════╝██╔══██╗██╔══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗│
│ ███████║███████║███████╗███████║    ██║     ██████╔╝███████║██║     █████╔╝ █████╗  ██████╔╝│
│ ██╔══██║██╔══██║╚════██║██╔══██║    ██║     ██╔══██╗██╔══██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗│
│ ██║  ██║██║  ██║███████║██║  ██║    ╚██████╗██║  ██║██║  ██║╚██████╗██║  ██╗███████╗██║  ██║│
│ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝     ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝│
│                                                                                             │
EOF
    banner_center_line "$version_text"
    banner_center_line "$progress_text"
    banner_center_line "$status_text"
    cat <<'EOF'
└─────────────────────────────────────────────────────────────────────────────────────────────┘

EOF
}

function menu_entries() {
    cat <<'EOF'
1|Brute force|scripts/processors/1-bruteforce.sh
2|Light rules|scripts/processors/2-light.sh
3|Heavy rules|scripts/processors/3-heavy.sh
4|Enter specific word/name/company|scripts/processors/4-word.sh
5|Enter specific word/name/company (brute force)|scripts/processors/5-word-bruteforce.sh
6|Hybrid|scripts/processors/6-hybrid.sh
7|Toggle-case|scripts/processors/7-toggle.sh
8|Combinator|scripts/processors/8-combinator.sh
9|Iterate results|scripts/processors/9-iterate.sh
10|Prefix suffix (advise: first run steps above)|scripts/processors/10-prefixsuffix.sh
11|Common substring (advise: first run steps above)|scripts/processors/11-commonsubstring.sh
12|PACK rulegen|scripts/processors/12-pack-rule.sh
13|PACK mask|scripts/processors/13-pack-mask.sh
14|Fingerprint attack|scripts/processors/14-fingerprint.sh
15|Directory of word lists plain and then with OneRuleToRuleThemAll|scripts/processors/15-multiple-wordlists.sh
16|Username iteration (only complete NTDS)|scripts/processors/16-usernameaspassword.sh
17|Markov-chain passwords generator|scripts/processors/17-markov-generator.sh
18|CeWL wordlist generator|scripts/processors/18-cewl.sh
19|Digit remover|scripts/processors/19-digitremover.sh
20|Stacker|scripts/processors/20-stacker.sh
21|Custom brute force|scripts/processors/21-custom-brute-force.sh
22|Directory of word lists plain and then with buka_400k|scripts/processors/22-multiple-wordlists-buka.sh
EOF
}

function print_job_list() {
    local option_id option_text processor

    while IFS='|' read -r option_id option_text processor; do
        echo "$option_id. $option_text"
    done < <(menu_entries)
    echo "99. Session stats dashboard"
}

function preset_entries() {
    cat <<'EOF'
quick|Quick baseline and iteration coverage|1,9
quick-plus|Quick coverage plus common substring pass|1,9,11
deep|Baseline, iteration, prefix/suffix, substring, and digit-remover coverage|1,9,10,11,19
deep-plus|Extended potfile-driven coverage with prefix/suffix and substring passes|1,9,10,11,14,19,9
EOF
}

function print_preset_list() {
    local preset_name preset_text preset_jobs

    while IFS='|' read -r preset_name preset_text preset_jobs; do
        printf '%s - %s (jobs: %s)\n' "$preset_name" "$preset_text" "$preset_jobs"
    done < <(preset_entries)
}

function run_early_list_mode() {
    local arg

    for arg in "$@"; do
        case "$arg" in
            --list-jobs)
                print_job_list
                exit 0
                ;;
            --list-presets)
                print_preset_list
                exit 0
                ;;
        esac
    done
}

function get_preset_jobs() {
    local selected="$1"
    local preset_name preset_text preset_jobs

    while IFS='|' read -r preset_name preset_text preset_jobs; do
        if [[ "$selected" == "$preset_name" ]]; then
            printf '%s' "$preset_jobs"
            return 0
        fi
    done < <(preset_entries)

    return 1
}

function job_text_by_id() {
    local selected="$1"
    local option_id option_text processor

    while IFS='|' read -r option_id option_text processor; do
        if [[ "$selected" == "$option_id" ]]; then
            printf '%s' "$option_text"
            return 0
        fi
    done < <(menu_entries)

    return 1
}

function preset_job_supported() {
    case "$1" in
        1 | 9 | 10 | 11 | 12 | 13 | 14 | 16 | 19) return 0 ;;
        *) return 1 ;;
    esac
}

function dependency_fail() {
    status_error "$1"
    printf '%b    Fix: %s%b\n' "$COLOR_RED" "$2" "$COLOR_RESET"
    return 1
}

function check_job_dependencies() {
    local selected="$1"
    local common_substr_bin
    local python_bin
    local statsgen
    local maskgen

    case "$selected" in
        10 | 11)
            if [ "$MACHINE" == "Mac" ]; then
                common_substr_bin="${COMMON_SUBSTR_BIN:-scripts/extensions/common-substr-mac}"
            else
                common_substr_bin="${COMMON_SUBSTR_BIN:-scripts/extensions/common-substr-linux}"
            fi
            if [ ! -x "$common_substr_bin" ]; then
                dependency_fail \
                    "Option $selected requires '$common_substr_bin'." \
                    "install/build common-substr and make it executable (e.g. chmod +x '$common_substr_bin')."
                return 1
            fi
            ;;
        12)
            if [ "$MACHINE" == "Mac" ]; then
                statsgen="scripts/extensions/pack-mac/rulegen.py"
            else
                statsgen="scripts/extensions/pack-linux/rulegen.py"
            fi
            if ! command -v python3 >/dev/null 2>&1; then
                dependency_fail \
                    "Option 12 requires 'python3'." \
                    "install python3 and ensure 'python3' is in PATH."
                return 1
            fi
            if [ ! -f "$statsgen" ]; then
                dependency_fail \
                    "Option 12 requires '$statsgen'." \
                    "restore the bundled PACK files under scripts/extensions/."
                return 1
            fi
            if ! python3 -c 'import enchant' >/dev/null 2>&1; then
                dependency_fail \
                    "Option 12 requires Python package 'pyenchant'." \
                    "install with 'python3 -m pip install pyenchant==3.3.0' and ensure enchant dictionaries are available."
                return 1
            fi
            ;;
        13)
            if [ "$MACHINE" == "Mac" ]; then
                python_bin="python3"
                statsgen="scripts/extensions/pack-mac/statsgen.py"
                maskgen="scripts/extensions/pack-mac/maskgen.py"
            else
                python_bin="python3"
                statsgen="scripts/extensions/pack-linux/statsgen.py"
                maskgen="scripts/extensions/pack-linux/maskgen.py"
            fi
            if ! command -v "$python_bin" >/dev/null 2>&1; then
                dependency_fail \
                    "Option 13 requires '$python_bin'." \
                    "install $python_bin and ensure it is in PATH."
                return 1
            fi
            if [ ! -f "$statsgen" ] || [ ! -f "$maskgen" ]; then
                dependency_fail \
                    "Option 13 requires PACK files '$statsgen' and '$maskgen'." \
                    "restore the bundled PACK files under scripts/extensions/."
                return 1
            fi
            ;;
        18)
            if [ -z "$CEWL" ] || [ ! -x "$CEWL" ]; then
                dependency_fail \
                    "Option 18 requires CeWL executable." \
                    "install CeWL (e.g. 'brew install cewl' or 'sudo apt install cewl') or provide executable at scripts/extensions/cewl/cewl.rb."
                return 1
            fi
            ;;
    esac

    return 0
}

function run_processor() {
    local selected="$1"
    local option_id option_text processor
    local selected_processor=""

    while IFS='|' read -r option_id option_text processor; do
        if [[ "$selected" == "$option_id" ]]; then
            selected_processor="$processor"
            break
        fi
    done < <(menu_entries)

    if [[ -z "$selected_processor" ]]; then
        return 1
    fi

    (
        # shellcheck source=/dev/null
        source "$selected_processor"
    )
    return 0
}

function hashcat_base() {
    "$HASHCAT" $KERNEL --bitmap-max=24 -d $DEVICE $HWMON $SHOWCRACKED --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST "$@"
}

function processor_bootstrap() {
    if [[ "$STATICCONFIG" = true ]]; then
        source hash-cracker.conf
        source scripts/runtime-overrides.sh
    else
        source scripts/selectors/hashtype.sh
        source scripts/selectors/hashlist.sh
    fi
}

function processor_cleanup() {
    local path
    for path in "$@"; do
        if [ -n "$path" ]; then
            rm -f -- "$path" 2>/dev/null || true
        fi
    done
}

function processor_interrupt() {
    processor_cleanup "$@"
    exit 0
}

function dry_run_enabled() {
    [ "$DRYRUN" = ' ' ]
}

function dryrun_note() {
    printf '[DRY-RUN] %s\n' "$*"
}

function dryrun_tempfile() {
    local tag="${1:-tmp}"
    if dry_run_enabled; then
        printf '/tmp/hash-cracker-dryrun-%s-%d-%d' "$tag" "$BASHPID" "$RANDOM"
    else
        mktemp /tmp/hash-cracker-tmp.XXXX
    fi
}

function count_file_lines() {
    local path="$1"
    if [ -f "$path" ]; then
        wc -l <"$path" | tr -d '[:space:]'
    else
        echo 0
    fi
}

function count_file_bytes() {
    local path="$1"
    if [ -f "$path" ]; then
        wc -c <"$path" | tr -d '[:space:]'
    else
        echo 0
    fi
}

function count_potfile_unique_plaintexts() {
    if [ -f "$POTFILE" ]; then
        awk -F: 'NF {print $NF}' "$POTFILE" | sort -u | wc -l | tr -d '[:space:]'
    else
        echo 0
    fi
}

function count_hashlist_unique_entries() {
    if [ -f "$HASHLIST" ]; then
        awk 'NF {print}' "$HASHLIST" | sort -u | wc -l | tr -d '[:space:]'
    else
        echo 0
    fi
}

function cleanup_session_state() {
    if [ -n "${SESSION_POT_UNIQUE_CACHE:-}" ]; then
        rm -f -- "$SESSION_POT_UNIQUE_CACHE" 2>/dev/null || true
    fi
}

function rebuild_unique_plaintext_cache() {
    if [ -f "$POTFILE" ]; then
        awk -F: 'NF {print $NF}' "$POTFILE" | LC_ALL=C sort -u >"$SESSION_POT_UNIQUE_CACHE"
    else
        : >"$SESSION_POT_UNIQUE_CACHE"
    fi
    SESSION_POT_UNIQUE_CUR=$(wc -l <"$SESSION_POT_UNIQUE_CACHE" | tr -d '[:space:]')
    stats_debug_note "Stats refresh mode: full recount (unique plaintext cache rebuilt: $SESSION_POT_UNIQUE_CUR)"
}

function update_unique_plaintexts_incremental() {
    local delta_lines="$1"
    local tmp_delta
    local tmp_merge
    local new_unique_lines

    if [ "$delta_lines" -le 0 ]; then
        return 0
    fi

    tmp_delta="$(mktemp /tmp/hash-cracker-unique-delta.XXXX)"
    tmp_merge="$(mktemp /tmp/hash-cracker-unique-merge.XXXX)"

    tail -n "$delta_lines" "$POTFILE" | awk -F: 'NF {print $NF}' | LC_ALL=C sort -u >"$tmp_delta"
    if [ ! -s "$tmp_delta" ]; then
        rm -f -- "$tmp_delta" "$tmp_merge"
        return 0
    fi

    if [ ! -f "$SESSION_POT_UNIQUE_CACHE" ]; then
        : >"$SESSION_POT_UNIQUE_CACHE"
    fi

    new_unique_lines=$(comm -13 "$SESSION_POT_UNIQUE_CACHE" "$tmp_delta" | wc -l | tr -d '[:space:]')
    if [ "$new_unique_lines" -gt 0 ]; then
        cat "$SESSION_POT_UNIQUE_CACHE" "$tmp_delta" | LC_ALL=C sort -u >"$tmp_merge"
        mv "$tmp_merge" "$SESSION_POT_UNIQUE_CACHE"
        SESSION_POT_UNIQUE_CUR=$((SESSION_POT_UNIQUE_CUR + new_unique_lines))
    fi
    stats_debug_note "Stats refresh mode: incremental (delta lines: $delta_lines, new unique plaintexts: $new_unique_lines)"

    rm -f -- "$tmp_delta" "$tmp_merge"
}

function signed_num() {
    local value="$1"
    if [ "$value" -ge 0 ]; then
        printf '+%s' "$value"
    else
        printf '%s' "$value"
    fi
}

function timestamp_now() {
    date '+%Y-%m-%d %H:%M:%S%z'
}

function stats_debug_enabled() {
    [ "$STATSDEBUG" = ' ' ]
}

function stats_debug_note() {
    if stats_debug_enabled; then
        status_heading "$1"
    fi
}

function json_escape() {
    local s="$1"
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    s=${s//$'\r'/\\r}
    s=${s//$'\t'/\\t}
    printf '%s' "$s"
}

function ensure_parent_dir() {
    local path="$1"
    local parent

    parent=$(dirname "$path")
    if [ -n "$parent" ] && [ "$parent" != "." ]; then
        mkdir -p "$parent" 2>/dev/null || true
    fi
}

function stats_export_scope() {
    local scope="${STATSEXPORT_SCOPE:-latest}"
    case "$scope" in
        latest | all) printf '%s' "$scope" ;;
        *) printf 'latest' ;;
    esac
}

function export_session_stats_history_json() {
    local logs_dir='logs'
    local first='1'
    local file
    local line
    local timestamp
    local message
    local new_lines
    local new_unique
    local growth_bytes
    local total_lines
    local input_unique

    printf '['

    if [ -d "$logs_dir" ]; then
        while IFS= read -r file; do
            while IFS= read -r line; do
                if [[ "$line" =~ ^\[([^]]+)\][[:space:]](.*)$ ]]; then
                    timestamp="${BASH_REMATCH[1]}"
                    message="${BASH_REMATCH[2]}"
                else
                    timestamp=''
                    message="$line"
                fi

                if [ "$first" = '1' ]; then
                    first='0'
                else
                    printf ','
                fi

                if [[ "$message" =~ ^Session\ stats:\ new\ ([+-]?[0-9]+)\ lines,\ ([+-]?[0-9]+)\ unique,\ ([+-]?[0-9]+)\ bytes\ \|\ total\ cracked\ passwords\ in\ potfile:\ ([0-9]+)\ lines\ \|\ input\ hashes:\ ([0-9]+)\ unique$ ]]; then
                    new_lines="${BASH_REMATCH[1]}"
                    new_unique="${BASH_REMATCH[2]}"
                    growth_bytes="${BASH_REMATCH[3]}"
                    total_lines="${BASH_REMATCH[4]}"
                    input_unique="${BASH_REMATCH[5]}"
                    printf '\n    { "timestamp": "%s", "source": "%s", "message": "%s", "session": { "new_cracks_lines": %s, "new_unique": %s, "growth_bytes": %s }, "potfile": { "total_cracked_lines": %s }, "input_hashes": { "unique": %s } }' \
                        "$(json_escape "$timestamp")" \
                        "$(json_escape "$file")" \
                        "$(json_escape "$message")" \
                        "$new_lines" \
                        "$new_unique" \
                        "$growth_bytes" \
                        "$total_lines" \
                        "$input_unique"
                else
                    printf '\n    { "timestamp": "%s", "source": "%s", "message": "%s" }' \
                        "$(json_escape "$timestamp")" \
                        "$(json_escape "$file")" \
                        "$(json_escape "$message")"
                fi
            done <"$file"
        done < <(find "$logs_dir" -maxdepth 1 -type f -name 'session-*.log' -print | LC_ALL=C sort)
    fi

    if [ "$first" = '0' ]; then
        printf '\n  '
    fi
    printf ']'
}

function export_session_stats_json() {
    local out_path="${STATSEXPORT:-}"
    local tmp_path
    local log_enabled
    local release_label
    local generated_at
    local export_scope
    local history_json

    if [ -z "$out_path" ]; then
        return 0
    fi

    ensure_parent_dir "$out_path"

    if [ "${SESSION_LOG_DISABLED:-0}" = '1' ]; then
        log_enabled="false"
    else
        log_enabled="true"
    fi

    release_label="$(release_version_text)"
    generated_at="$(timestamp_now)"
    export_scope="$(stats_export_scope)"
    history_json='[]'
    if [ "$export_scope" = 'all' ]; then
        history_json="$(export_session_stats_history_json)"
    fi
    tmp_path="${out_path}.tmp.$$"

    cat >"$tmp_path" <<EOF
{
  "schema_version": "1",
  "generated_at": "$(json_escape "$generated_at")",
  "export_scope": "$(json_escape "$export_scope")",
  "release": "$(json_escape "$release_label")",
  "hashtype": "$(json_escape "${HASHTYPE_DISPLAY:-$HASHTYPE}")",
  "hashlist": "$(json_escape "$HASHLIST")",
  "potfile": "$(json_escape "$POTFILE")",
  "session": {
    "new_cracks_lines": $SESSION_NEW_CRACKS,
    "new_unique": $SESSION_NEW_UNIQUE,
    "growth_bytes": $SESSION_GROWTH_BYTES
  },
  "potfile_totals": {
    "lines": $SESSION_POT_LINES_CUR,
    "unique_plaintexts": $SESSION_POT_UNIQUE_CUR,
    "bytes": $SESSION_POT_BYTES_CUR
  },
  "input_hashes": {
    "unique": $SESSION_HASHLIST_INPUT_UNIQUE
  },
  "logging": {
    "enabled": $log_enabled,
    "keep": $(session_log_keep_count),
    "path": "$(json_escape "${SESSION_STATS_LOGFILE:-}")"
  },
  "history": $history_json
}
EOF

    mv "$tmp_path" "$out_path" 2>/dev/null || true
}

function session_log_keep_count() {
    case "${SESSION_LOG_KEEP:-}" in
        '' | *[!0-9]*) echo 0 ;;
        *) echo "$SESSION_LOG_KEEP" ;;
    esac
}

function prune_session_logs() {
    local logs_dir="$1"
    local keep_count="$2"
    local files
    local total
    local prune_count

    case "$keep_count" in
        '' | *[!0-9]*) keep_count=0 ;;
    esac

    if [ "$keep_count" -eq 0 ]; then
        return 0
    fi

    files=$(find "$logs_dir" -maxdepth 1 -type f -name 'session-*.log' -print | sort)
    if [ -z "$files" ]; then
        return 0
    fi

    total=$(printf '%s\n' "$files" | wc -l | tr -d '[:space:]')
    prune_count=$((total - keep_count + 1))
    if [ "$prune_count" -le 0 ]; then
        return 0
    fi

    printf '%s\n' "$files" | head -n "$prune_count" | while IFS= read -r file; do
        rm -f -- "$file"
    done
}

function init_session_stats_logfile() {
    local logs_dir='logs'
    local log_dir
    local session_stamp
    local keep_count

    if [ "${SESSION_LOG_DISABLED:-0}" = '1' ]; then
        SESSION_STATS_LOGFILE=''
        return 0
    fi

    keep_count=$(session_log_keep_count)

    if [ -n "${SESSION_STATS_LOGFILE:-}" ]; then
        log_dir=$(dirname "$SESSION_STATS_LOGFILE")
        if [ -n "$log_dir" ] && [ "$log_dir" != "." ]; then
            mkdir -p "$log_dir" 2>/dev/null || true
        fi
        return 0
    fi

    session_stamp=$(date '+%Y%m%d-%H%M%S')
    SESSION_STATS_LOGFILE="$logs_dir/session-${session_stamp}-${BASHPID}.log"

    mkdir -p "$logs_dir" 2>/dev/null || true
    prune_session_logs "$logs_dir" "$keep_count"
    ln -sfn "$(basename "$SESSION_STATS_LOGFILE")" "$logs_dir/latest.log" 2>/dev/null || true
}

function log_session_stats_line() {
    local line="$1"
    if [ -z "${SESSION_STATS_LOGFILE:-}" ]; then
        return 0
    fi

    printf '[%s] %s\n' "$(timestamp_now)" "$line" >>"$SESSION_STATS_LOGFILE" 2>/dev/null || true
}

function dashboard_line() {
    local label="$1"
    local value="$2"
    printf '| %-36s | %-54s |\n' "$label" "$value"
}

function show_session_stats_dashboard() {
    local session_stats_line
    local log_state
    local keep_count
    local log_path
    local release_text

    if [ "${SESSION_LOG_DISABLED:-0}" = '1' ]; then
        log_state="disabled"
    else
        log_state="enabled"
    fi

    keep_count=$(session_log_keep_count)
    log_path="${SESSION_STATS_LOGFILE:-n/a}"
    release_text="$(release_version_text)"
    session_stats_line="new $(signed_num "$SESSION_NEW_CRACKS") lines, $(signed_num "$SESSION_NEW_UNIQUE") unique, $(signed_num "$SESSION_GROWTH_BYTES") bytes"

    echo
    echo "+--------------------------------------+--------------------------------------------------------+"
    dashboard_line "Session Stats Dashboard" "$(release_label_text)"
    echo "+--------------------------------------+--------------------------------------------------------+"
    dashboard_line "Generated at" "$(timestamp_now)"
    dashboard_line "Release" "$release_text"
    dashboard_line "Hashtype" "${HASHTYPE_DISPLAY:-$HASHTYPE}"
    dashboard_line "Hashlist" "$HASHLIST"
    dashboard_line "Potfile" "$POTFILE"
    dashboard_line "Session delta" "$session_stats_line"
    dashboard_line "Total cracked lines in potfile" "$SESSION_POT_LINES_CUR"
    dashboard_line "Total unique plaintexts in potfile" "$SESSION_POT_UNIQUE_CUR"
    dashboard_line "Unique input hashes" "$SESSION_HASHLIST_INPUT_UNIQUE"
    dashboard_line "Session logging" "$log_state"
    dashboard_line "Session log keep" "$keep_count"
    dashboard_line "Session log file" "$log_path"
    dashboard_line "Stats export file" "${STATSEXPORT:-n/a}"
    echo "+--------------------------------------+--------------------------------------------------------+"
    echo
}

function build_session_stats_line() {
    printf 'Session stats: new %s lines, %s unique, %s bytes | total cracked passwords in potfile: %s lines | input hashes: %s unique' \
        "$(signed_num "$SESSION_NEW_CRACKS")" \
        "$(signed_num "$SESSION_NEW_UNIQUE")" \
        "$(signed_num "$SESSION_GROWTH_BYTES")" \
        "$SESSION_POT_LINES_CUR" \
        "$SESSION_HASHLIST_INPUT_UNIQUE"
}

function init_session_stats() {
    SESSION_POT_LINES_BASE=$(count_file_lines "$POTFILE")
    SESSION_POT_BYTES_BASE=$(count_file_bytes "$POTFILE")
    SESSION_POT_UNIQUE_BASE=0

    SESSION_POT_LINES_CUR="$SESSION_POT_LINES_BASE"
    SESSION_POT_BYTES_CUR="$SESSION_POT_BYTES_BASE"
    SESSION_POT_UNIQUE_CUR=0

    SESSION_POT_LINES_LAST="$SESSION_POT_LINES_CUR"
    SESSION_POT_BYTES_LAST="$SESSION_POT_BYTES_CUR"

    SESSION_NEW_CRACKS=0
    SESSION_NEW_UNIQUE=0
    SESSION_GROWTH_BYTES=0

    SESSION_HASHLIST_PATH_LAST="$HASHLIST"
    SESSION_HASHLIST_INPUT_UNIQUE=$(count_hashlist_unique_entries)
    SESSION_POT_UNIQUE_CACHE="/tmp/hash-cracker-unique-${BASHPID}.cache"
    rebuild_unique_plaintext_cache
    SESSION_POT_UNIQUE_BASE="$SESSION_POT_UNIQUE_CUR"
    init_session_stats_logfile
}

function refresh_session_stats() {
    local delta_lines

    SESSION_POT_LINES_CUR=$(count_file_lines "$POTFILE")
    SESSION_POT_BYTES_CUR=$(count_file_bytes "$POTFILE")

    if [ "$SESSION_POT_LINES_CUR" -ne "$SESSION_POT_LINES_LAST" ] || [ "$SESSION_POT_BYTES_CUR" -ne "$SESSION_POT_BYTES_LAST" ]; then
        if [ "$SESSION_POT_LINES_CUR" -ge "$SESSION_POT_LINES_LAST" ] && [ "$SESSION_POT_BYTES_CUR" -ge "$SESSION_POT_BYTES_LAST" ]; then
            delta_lines=$((SESSION_POT_LINES_CUR - SESSION_POT_LINES_LAST))
            update_unique_plaintexts_incremental "$delta_lines"
        else
            status_heading "Refreshing session stats (recounting unique potfile plaintexts, this may take a moment)..."
            rebuild_unique_plaintext_cache
        fi
        SESSION_POT_LINES_LAST="$SESSION_POT_LINES_CUR"
        SESSION_POT_BYTES_LAST="$SESSION_POT_BYTES_CUR"
    fi

    SESSION_NEW_CRACKS=$((SESSION_POT_LINES_CUR - SESSION_POT_LINES_BASE))
    SESSION_NEW_UNIQUE=$((SESSION_POT_UNIQUE_CUR - SESSION_POT_UNIQUE_BASE))
    SESSION_GROWTH_BYTES=$((SESSION_POT_BYTES_CUR - SESSION_POT_BYTES_BASE))

    if [ "$SESSION_NEW_CRACKS" -lt 0 ]; then
        SESSION_NEW_CRACKS=0
    fi
    if [ "$SESSION_NEW_UNIQUE" -lt 0 ]; then
        SESSION_NEW_UNIQUE=0
    fi

    if [ "$HASHLIST" != "$SESSION_HASHLIST_PATH_LAST" ]; then
        SESSION_HASHLIST_PATH_LAST="$HASHLIST"
        SESSION_HASHLIST_INPUT_UNIQUE=$(count_hashlist_unique_entries)
    fi
}

function run_self_test() {
    local failures=0
    local option_id option_text processor

    echo
    status_heading "Self-test: configuration and dependency checks"

    echo -e "\nConfiguration paths:"
    if [ -f "$HASHLIST" ]; then
        status_ok "HASHLIST exists: $HASHLIST"
    else
        status_bad "HASHLIST missing: $HASHLIST"
        printf '%b    Fix: set HASHLIST to an existing file in hash-cracker.conf%b\n' "$COLOR_RED" "$COLOR_RESET"
        ((failures = failures + 1))
    fi

    if [ -f "$WORDLIST" ]; then
        status_ok "WORDLIST exists: $WORDLIST"
    else
        status_bad "WORDLIST missing: $WORDLIST"
        printf '%b    Fix: set WORDLIST to an existing file in hash-cracker.conf%b\n' "$COLOR_RED" "$COLOR_RESET"
        ((failures = failures + 1))
    fi

    if [ -f "$WORDLIST2" ]; then
        status_ok "WORDLIST2 exists: $WORDLIST2"
    else
        status_bad "WORDLIST2 missing: $WORDLIST2"
        printf '%b    Fix: set WORDLIST2 to an existing file in hash-cracker.conf%b\n' "$COLOR_RED" "$COLOR_RESET"
        ((failures = failures + 1))
    fi

    if [ "$DRYRUN" = ' ' ]; then
        status_ok "HASHCAT executable check skipped (dry-run mode)"
    elif [ -x "$HASHCAT_BIN" ] || command -v "$HASHCAT_BIN" >/dev/null 2>&1; then
        status_ok "HASHCAT executable available: $HASHCAT_BIN"
    else
        status_bad "HASHCAT executable missing/unusable: $HASHCAT_BIN"
        printf '%b    Fix: set HASHCAT to a valid executable path in hash-cracker.conf%b\n' "$COLOR_RED" "$COLOR_RESET"
        ((failures = failures + 1))
    fi

    echo -e "\nJob-specific checks:"
    while IFS='|' read -r option_id option_text processor; do
        if check_job_dependencies "$option_id"; then
            status_ok "Option $option_id ($option_text): OK"
        else
            status_bad "Option $option_id ($option_text): missing dependency"
            ((failures = failures + 1))
        fi
    done < <(menu_entries)

    echo
    if [ "$failures" -gt 0 ]; then
        status_error "Self-test failed: $failures issue(s) found."
        return 1
    fi

    status_ok "Self-test passed: all checks succeeded."
    return 0
}

function run_single_job_mode() {
    local selected="$1"
    local rc
    local session_stats_line

    refresh_session_stats
    session_stats_line=$(build_session_stats_line)
    log_session_stats_line "$session_stats_line"
    export_session_stats_json

    if [ "$selected" = "99" ]; then
        show_session_stats_dashboard
        return 0
    fi

    case "$selected" in
        4 | 5 | 8 | 15 | 17 | 18 | 21 | 22)
            if [ ! -t 0 ]; then
                status_error "Job $selected requires interactive input and cannot run in non-interactive --job mode."
                status_heading "Use --list-jobs and choose a non-prompting job, or run interactively."
                return 1
            fi
            ;;
    esac

    if ! check_job_dependencies "$selected"; then
        return 1
    fi

    if ! run_processor "$selected"; then
        status_error "Invalid job selection for --job: $selected"
        status_heading "Use --list-jobs to see available options."
        return 1
    fi
    rc=$?

    refresh_session_stats
    session_stats_line=$(build_session_stats_line)
    log_session_stats_line "$session_stats_line"
    export_session_stats_json

    return $rc
}

function run_preset_mode() {
    local preset_name="$1"
    local preset_jobs
    local job_id
    local job_text
    local rc
    local session_stats_line
    local -a preset_job_ids

    if ! preset_jobs="$(get_preset_jobs "$preset_name")"; then
        status_error "Invalid preset: $preset_name"
        status_heading "Use --list-presets to see available presets."
        return 1
    fi

    IFS=',' read -ra preset_job_ids <<<"$preset_jobs"
    for job_id in "${preset_job_ids[@]}"; do
        if ! preset_job_supported "$job_id"; then
            status_error "Preset '$preset_name' contains unsupported non-interactive job: $job_id"
            status_heading "Presets currently support jobs 1, 9, 10, 11, 12, 13, 14, 16, and 19."
            return 1
        fi
        if ! job_text="$(job_text_by_id "$job_id")"; then
            status_error "Preset '$preset_name' contains unknown job: $job_id"
            status_heading "Use --list-jobs to see available jobs."
            return 1
        fi
    done

    refresh_session_stats
    session_stats_line=$(build_session_stats_line)
    log_session_stats_line "$session_stats_line"
    export_session_stats_json

    status_heading "Running preset '$preset_name' (jobs: $preset_jobs)"
    for job_id in "${preset_job_ids[@]}"; do
        job_text="$(job_text_by_id "$job_id")"
        status_heading "Preset '$preset_name': running job $job_id ($job_text)"

        if ! check_job_dependencies "$job_id"; then
            status_error "Preset '$preset_name' failed before job $job_id ($job_text): missing dependency."
            return 1
        fi

        run_processor "$job_id"
        rc=$?
        if [ "$rc" -ne 0 ]; then
            status_error "Preset '$preset_name' failed at job $job_id ($job_text)."
            return "$rc"
        fi

        refresh_session_stats
        session_stats_line=$(build_session_stats_line)
        log_session_stats_line "$session_stats_line"
        export_session_stats_json
    done

    status_ok "Preset '$preset_name' completed."
    return 0
}

function menu() {
    local option_id option_text processor
    local session_stats_line

    while true; do
        refresh_session_stats
        echo -e "\n0. Exit"
        print_job_list
        echo
        session_stats_line=$(build_session_stats_line)
        log_session_stats_line "$session_stats_line"
        export_session_stats_json

        if [ "$DRYRUN" = ' ' ]; then
            read -r -p "Select job [0-22,99] or type exit [DRY-RUN MODE]: " START
        else
            read -r -p "Select job [0-22,99] or type exit: " START
        fi
        START="${START#"${START%%[![:space:]]*}"}"
        START="${START%"${START##*[![:space:]]}"}"

        if [[ -z "$START" ]]; then
            continue
        fi

        case "$START" in
            0 | exit | quit | q)
                echo "Bye..."
                exit 0
                ;;
            99)
                show_session_stats_dashboard
                continue
                ;;
        esac

        if ! check_job_dependencies "$START"; then
            echo
            continue
        fi

        if ! run_processor "$START"; then
            echo -e "Not valid, try again\n"
            continue
        fi

        source scripts/parameters.sh "$@"
    done
}

run_early_list_mode "$@"
init_colors
trap cleanup_session_state EXIT
source scripts/parameters.sh "$@"
status_heading "Preparing session stats (counting potfile and input hashes)..."
init_session_stats

if [ "$JOBLIST" = ' ' ]; then
    print_job_list
    exit 0
fi

if [ "$PRESETLIST" = ' ' ]; then
    print_preset_list
    exit 0
fi

if [ "$SELFTEST" = ' ' ]; then
    run_self_test
    exit $?
fi

if [ -n "${PRESETMODE:-}" ] && [ -n "${JOBMODE:-}" ]; then
    status_error "Use either --preset or --job, not both."
    exit 1
fi

if [ -n "${PRESETMODE:-}" ]; then
    run_preset_mode "$PRESETMODE"
    exit $?
fi

if [ -n "${JOBMODE:-}" ]; then
    run_single_job_mode "$JOBMODE"
    exit $?
fi

menu "$@"
