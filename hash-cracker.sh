#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

CAMPAIGN_EPHEMERAL_FILES=()

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
    printf '%s' 'v6.8.0 "Hardware Bridge"'
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

function processor_path_by_id() {
    local selected="$1"
    local option_id option_text processor

    while IFS='|' read -r option_id option_text processor; do
        if [[ "$selected" == "$option_id" ]]; then
            printf '%s' "$processor"
            return 0
        fi
    done < <(menu_entries)

    return 1
}

function current_epoch_seconds() {
    date '+%s'
}

function format_duration() {
    local seconds="$1"
    local hours
    local minutes
    local remainder

    if [ -z "$seconds" ] || [ "$seconds" -lt 0 ]; then
        seconds=0
    fi

    hours=$((seconds / 3600))
    remainder=$((seconds % 3600))
    minutes=$((remainder / 60))
    seconds=$((remainder % 60))

    printf '%02d:%02d:%02d' "$hours" "$minutes" "$seconds"
}

function print_job_timing_result() {
    local job_id="$1"
    local job_text="$2"
    local rc="$3"
    local duration="$4"

    if [ "$rc" -eq 0 ]; then
        status_ok "Job $job_id ($job_text) completed in $duration"
    else
        status_error "Job $job_id ($job_text) failed with rc=$rc after $duration"
    fi
}

function print_preset_summary() {
    local preset_name="$1"
    local planned="$2"
    local completed="$3"
    local failed="$4"
    local total_duration="$5"
    local rows="$6"
    local job_id
    local job_text
    local result
    local rc
    local duration

    echo
    status_heading "Preset '$preset_name' summary"
    printf '+--------+------------------------------------------------+---------+------+----------+\n'
    printf '| %-6s | %-46s | %-7s | %-4s | %-8s |\n' "Job" "Name" "Result" "RC" "Duration"
    printf '+--------+------------------------------------------------+---------+------+----------+\n'
    while IFS='|' read -r job_id job_text result rc duration; do
        [ -z "$job_id" ] && continue
        printf '| %-6s | %-46.46s | %-7s | %-4s | %-8s |\n' "$job_id" "$job_text" "$result" "$rc" "$duration"
    done <<<"$rows"
    printf '+--------+------------------------------------------------+---------+------+----------+\n'
    printf 'Preset: %s | planned: %s | completed: %s | failed: %s | duration: %s\n' \
        "$preset_name" "$planned" "$completed" "$failed" "$total_duration"
    echo
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
            if [ "$DRYRUN" != ' ' ] && ! command -v python3 >/dev/null 2>&1; then
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
            if [ "$DRYRUN" != ' ' ] && ! python3 -c 'import enchant' >/dev/null 2>&1; then
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
            if [ "$DRYRUN" != ' ' ] && ! command -v "$python_bin" >/dev/null 2>&1; then
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
    local rc

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
        HASHCAT_FAILURE=0
        PROCESSOR_FAILURE=0
        set -o pipefail
        # shellcheck source=/dev/null
        source "$selected_processor"
        rc=$?
        if [ "$rc" -ne 0 ]; then
            exit "$rc"
        fi
        if [ "$PROCESSOR_FAILURE" -ne 0 ]; then
            exit "$PROCESSOR_FAILURE"
        fi
        if [ "$HASHCAT_FAILURE" -ne 0 ]; then
            exit "$HASHCAT_FAILURE"
        fi
    )
    rc=$?
    if [ -n "${CAMPAIGN_INTERRUPT_MARKER:-}" ] && [ -f "$CAMPAIGN_INTERRUPT_MARKER" ]; then
        if [ "$rc" -ne 0 ] && [ "$rc" -ne 130 ]; then
            return "$rc"
        fi
        return 130
    fi
    return "$rc"
}

function campaign_record_command() {
    local command_line="$1"
    shift
    if ! python3 - "$CAMPAIGN_CURRENT_STEP" "$command_line" "$@" >>"$CAMPAIGN_COMMAND_FILE" <<'PY'; then
import json
import sys

print(json.dumps({"step_id": sys.argv[1], "preview": sys.argv[2], "argv": sys.argv[3:]}))
PY
        status_error "Unable to record campaign command arguments."
        return 1
    fi
    return 0
}

function campaign_register_ephemeral() {
    local path

    for path in "$@"; do
        if [ -n "$path" ]; then
            CAMPAIGN_EPHEMERAL_FILES+=("$path")
        fi
    done
}

function campaign_command_start() {
    local result

    if [ "${CAMPAIGN_MODE:-}" != 'execute' ]; then
        return 0
    fi
    if [ -z "${CAMPAIGN_MANIFEST:-}" ]; then
        status_error "Campaign command checkpoint is missing its manifest path."
        return 1
    fi

    if ! result="$(python3 scripts/campaign.py command-start \
        --manifest "$CAMPAIGN_MANIFEST" \
        --index "$CAMPAIGN_STEP_INDEX" \
        --step-id "$CAMPAIGN_STEP_ID" \
        --command-index "$CAMPAIGN_COMMAND_INDEX")"; then
        status_error "Unable to checkpoint campaign command $CAMPAIGN_COMMAND_INDEX."
        return 1
    fi

    IFS=$'\t' read -r CAMPAIGN_COMMAND_STATE CAMPAIGN_SESSION_NAME \
        CAMPAIGN_RESTORE_FILE CAMPAIGN_RESTORE CAMPAIGN_COMMAND_ARGS_FILE <<<"$result"
    CAMPAIGN_COMMAND_INDEX=$((CAMPAIGN_COMMAND_INDEX + 1))
    return 0
}

function campaign_command_record() {
    local command_index="$1"
    local preview="$2"
    shift 2
    local argv_file

    if [ "${CAMPAIGN_MODE:-}" != 'execute' ]; then
        return 0
    fi
    if ! argv_file=$(mktemp /tmp/hash-cracker-campaign-argv.XXXX); then
        status_error "Unable to allocate campaign command argument storage."
        return 1
    fi
    campaign_register_ephemeral "$argv_file"
    if ! printf '%s\0' "$@" >"$argv_file"; then
        rm -f -- "$argv_file"
        status_error "Unable to stage campaign command arguments."
        return 1
    fi
    if ! python3 scripts/campaign.py command-record \
        --manifest "$CAMPAIGN_MANIFEST" \
        --index "$CAMPAIGN_STEP_INDEX" \
        --step-id "$CAMPAIGN_STEP_ID" \
        --command-index "$command_index" \
        --preview "$preview" \
        --argv-file "$argv_file"; then
        rm -f -- "$argv_file"
        status_error "Unable to persist campaign command $command_index arguments."
        return 1
    fi
    rm -f -- "$argv_file"
    return 0
}

function campaign_command_preserve_inputs() {
    local path
    local -a preserve_args=()

    if [ "${CAMPAIGN_MODE:-}" != 'execute' ]; then
        return 0
    fi
    for path in "$@"; do
        if [ -n "$path" ]; then
            CAMPAIGN_PRESERVED_PATHS+=("$path")
            preserve_args+=(--path "$path")
        fi
    done
    if [ "${#preserve_args[@]}" -eq 0 ]; then
        return 0
    fi
    if ! python3 scripts/campaign.py command-preserve \
        --manifest "$CAMPAIGN_MANIFEST" \
        --index "$CAMPAIGN_STEP_INDEX" \
        --step-id "$CAMPAIGN_STEP_ID" \
        --command-index "$CAMPAIGN_ACTIVE_COMMAND_INDEX" \
        "${preserve_args[@]}"; then
        status_error "Unable to preserve campaign command inputs."
        return 1
    fi
    return 0
}

function campaign_command_finish() {
    local command_index="$1"
    local rc="$2"
    local duration="$3"
    local state='failed'

    if [ "${CAMPAIGN_MODE:-}" != 'execute' ]; then
        return 0
    fi
    if [ "$rc" -eq 0 ]; then
        state='completed'
    fi
    if ! python3 scripts/campaign.py command-finish \
        --manifest "$CAMPAIGN_MANIFEST" \
        --index "$CAMPAIGN_STEP_INDEX" \
        --step-id "$CAMPAIGN_STEP_ID" \
        --command-index "$command_index" \
        --state "$state" \
        --exit-code "$rc" \
        --duration "$duration"; then
        status_error "Unable to persist campaign command $command_index state."
        return 1
    fi
    return 0
}

function campaign_jobs_for_source() {
    local source="$1"

    if [[ "$source" =~ ^[0-9]+$ ]]; then
        if ! preset_job_supported "$source"; then
            status_error "Campaign job '$source' requires interactive input or is unsupported." >&2
            status_heading "Campaigns support non-interactive jobs 1, 9, 10, 11, 12, 13, 14, 16, and 19." >&2
            return 1
        fi
        printf '%s' "$source"
        return 0
    fi

    if ! get_preset_jobs "$source"; then
        status_error "Invalid campaign preset: $source" >&2
        status_heading "Use --list-presets to see available campaign sources." >&2
        return 1
    fi
}

function campaign_artifact_paths() {
    local path

    printf '%s\n' \
        "$HASHCAT_BIN" \
        hash-cracker.sh \
        scripts/parameters.sh \
        scripts/campaign.py \
        scripts/linux.sh \
        scripts/mac.sh \
        scripts/runtime-overrides.sh \
        scripts/extensions/hashtypes
    find scripts/processors scripts/selectors scripts/rules \
        scripts/extensions/pack-linux scripts/extensions/pack-mac \
        -type f \( -name '*.sh' -o -name '*.config' -o -name '*.py' \) -print 2>/dev/null | LC_ALL=C sort
    for path in \
        "${COMMON_SUBSTR_BIN:-}" \
        "${EXPANDER_BIN:-}" \
        "${MKPASS_BIN:-}" \
        "${CEWL:-}"; do
        if [ -n "$path" ] && [ -f "$path" ]; then
            printf '%s\n' "$path"
        fi
    done
}

function campaign_artifact_args() {
    local artifact

    CAMPAIGN_ARTIFACT_ARGS=()
    while IFS= read -r artifact; do
        if [ -n "$artifact" ]; then
            CAMPAIGN_ARTIFACT_ARGS+=(--artifact "$artifact")
        fi
    done < <(campaign_artifact_paths)
}

function run_campaign_plan() {
    local source="$1"
    local output="$2"
    local jobs
    local step_file
    local command_file
    local job_id
    local job_text
    local processor
    local step_id
    local index=1
    local rc
    local kind='preset'
    local -a job_ids
    local -a campaign_args

    if [[ "$source" =~ ^[0-9]+$ ]]; then
        kind='job'
    fi
    if ! jobs="$(campaign_jobs_for_source "$source")"; then
        return 1
    fi

    if ! step_file=$(mktemp /tmp/hash-cracker-campaign-steps.XXXX); then
        status_error "Unable to allocate campaign planning state."
        return 1
    fi
    if ! command_file=$(mktemp /tmp/hash-cracker-campaign-commands.XXXX); then
        rm -f -- "$step_file"
        status_error "Unable to allocate campaign command state."
        return 1
    fi
    campaign_register_ephemeral "$step_file" "$command_file"
    : >"$command_file"
    CAMPAIGN_MODE='plan'
    CAMPAIGN_COMMAND_FILE="$command_file"
    status_heading "Planning campaign '$source' (jobs: $jobs)"

    IFS=',' read -ra job_ids <<<"$jobs"
    for job_id in "${job_ids[@]}"; do
        if ! job_text="$(job_text_by_id "$job_id")" || ! processor="$(processor_path_by_id "$job_id")"; then
            status_error "Campaign source '$source' contains unknown job: $job_id"
            rm -f -- "$step_file" "$command_file"
            return 1
        fi

        step_id=$(printf 'step-%03d-job-%s' "$index" "$job_id")
        printf '%s\t%s\t%s\t%s\n' "$step_id" "$job_id" "$job_text" "$processor" >>"$step_file"
        CAMPAIGN_CURRENT_STEP="$step_id"
        if ! check_job_dependencies "$job_id"; then
            status_error "Campaign '$source' cannot plan job $job_id ($job_text)."
            rm -f -- "$step_file" "$command_file"
            return 1
        fi
        CAMPAIGN_TEMP_INDEX=0
        run_processor "$job_id"
        rc=$?
        if [ "$rc" -ne 0 ]; then
            status_error "Campaign '$source' failed to plan job $job_id ($job_text)."
            rm -f -- "$step_file" "$command_file"
            return "$rc"
        fi
        index=$((index + 1))
    done

    campaign_artifact_args
    campaign_args=(
        python3 scripts/campaign.py create
        --output "$output"
        --name "$source"
        --kind "$kind"
        --release "$(release_version_text)"
        --steps-file "$step_file"
        --commands-file "$command_file"
        --config "$CONFIGFILE"
        --hashlist "$HASHLIST"
        --potfile "$POTFILE"
        --wordlist "$WORDLIST"
        --wordlist2 "$WORDLIST2"
        --hashcat "$HASHCAT_BIN"
        --hashtype "$HASHTYPE"
        --machine "$MACHINE"
        --kernel="$KERNEL"
        --loopback="$LOOPBACK"
        --hwmon="$HWMON"
        --showcracked="$SHOWCRACKED"
    )
    campaign_args+=("${CAMPAIGN_ARTIFACT_ARGS[@]}")
    "${campaign_args[@]}"
    rc=$?
    rm -f -- "$step_file" "$command_file"
    if [ "$rc" -eq 0 ]; then
        status_ok "Campaign plan ready: $output"
    fi
    return "$rc"
}

function run_campaign_execute() {
    local manifest="$1"
    local action="$2"
    local next_line
    local next_rc
    local index
    local step_id
    local job_id
    local job_text
    local command_file
    local interrupt_marker
    local start_time
    local duration
    local rc
    local state
    local update_rc
    local session_stats_line
    local -a campaign_args

    if [ ! -f "$manifest" ]; then
        status_error "Campaign manifest not found: $manifest"
        return 1
    fi
    campaign_artifact_args
    campaign_args=(
        python3 scripts/campaign.py validate
        --manifest "$manifest"
        --config "$CONFIGFILE"
        --hashlist "$HASHLIST"
        --wordlist "$WORDLIST"
        --wordlist2 "$WORDLIST2"
        --hashcat "$HASHCAT_BIN"
        --hashtype "$HASHTYPE"
        --machine "$MACHINE"
        --kernel="$KERNEL"
        --loopback="$LOOPBACK"
        --hwmon="$HWMON"
        --showcracked="$SHOWCRACKED"
    )
    campaign_args+=("${CAMPAIGN_ARTIFACT_ARGS[@]}")
    if ! "${campaign_args[@]}"; then
        return 1
    fi

    status_heading "${action^} campaign: $manifest"
    while true; do
        next_line="$(python3 scripts/campaign.py next --manifest "$manifest")"
        next_rc=$?
        if [ "$next_rc" -eq 2 ]; then
            status_ok "Campaign has no incomplete steps: $manifest"
            return 0
        fi
        if [ "$next_rc" -ne 0 ]; then
            status_error "Unable to read the next campaign step."
            return "$next_rc"
        fi

        IFS='|' read -r index step_id job_id job_text <<<"$next_line"
        status_heading "Campaign step $step_id: job $job_id ($job_text)"
        if ! python3 scripts/campaign.py mark-running \
            --manifest "$manifest" \
            --index "$index" \
            --step-id "$step_id"; then
            return 1
        fi

        if ! command_file=$(mktemp /tmp/hash-cracker-campaign-executed.XXXX); then
            status_error "Unable to allocate campaign execution state."
            return 1
        fi
        interrupt_marker="${command_file}.interrupt"
        campaign_register_ephemeral "$command_file" "$interrupt_marker"
        : >"$command_file"
        rm -f -- "$interrupt_marker"
        # shellcheck disable=SC2034
        CAMPAIGN_MODE='execute'
        CAMPAIGN_CURRENT_STEP="$step_id"
        CAMPAIGN_MANIFEST="$manifest"
        CAMPAIGN_STEP_INDEX="$index"
        CAMPAIGN_STEP_ID="$step_id"
        CAMPAIGN_COMMAND_INDEX=0
        CAMPAIGN_TEMP_INDEX=0
        CAMPAIGN_ACTIVE_COMMAND_INDEX=-1
        CAMPAIGN_PRESERVED_PATHS=()
        CAMPAIGN_COMMAND_FILE="$command_file"
        CAMPAIGN_INTERRUPT_MARKER="$interrupt_marker"
        start_time=$(current_epoch_seconds)

        if ! check_job_dependencies "$job_id"; then
            rc=1
        else
            run_processor "$job_id"
            rc=$?
        fi
        duration=$(($(current_epoch_seconds) - start_time))
        if [ "$rc" -eq 0 ]; then
            state='completed'
        elif [ "$rc" -eq 130 ]; then
            state='interrupted'
        else
            state='failed'
        fi

        python3 scripts/campaign.py update \
            --manifest "$manifest" \
            --index "$index" \
            --step-id "$step_id" \
            --state "$state" \
            --exit-code "$rc" \
            --duration "$duration" \
            --commands-file "$command_file"
        update_rc=$?
        rm -f -- "$command_file" "$interrupt_marker"
        if [ "$update_rc" -ne 0 ]; then
            return "$update_rc"
        fi

        refresh_session_stats
        session_stats_line=$(build_session_stats_line)
        log_session_stats_line "$session_stats_line"
        if ! export_session_stats_json; then
            return 1
        fi

        if [ "$rc" -ne 0 ]; then
            status_error "Campaign '$manifest' stopped at $step_id with rc=$rc."
            return "$rc"
        fi
    done
}

function hashcat_base() {
    local -a hashcat_args=()
    local -a processor_args=()
    local arg

    if [ -n "$KERNEL" ] && [ "$KERNEL" != ' ' ]; then
        hashcat_args+=("$KERNEL")
    fi
    hashcat_args+=(--bitmap-max=24 -d "$DEVICE")
    if [ -n "$HWMON" ] && [ "$HWMON" != ' ' ]; then
        hashcat_args+=("$HWMON")
    fi
    case "$SHOWCRACKED" in
        '' | ' ') ;;
        '-o /dev/null') hashcat_args+=(-o /dev/null) ;;
        *) hashcat_args+=("$SHOWCRACKED") ;;
    esac
    hashcat_args+=("--potfile-path=$POTFILE" "-m$HASHTYPE" "$HASHLIST")

    for arg in "$@"; do
        if [ -n "$arg" ] && [ "$arg" != ' ' ]; then
            processor_args+=("$arg")
        fi
    done

    "$HASHCAT" "${hashcat_args[@]}" "${processor_args[@]}"
}

function processor_run() {
    local rc

    "$@"
    rc=$?
    if [ "$rc" -ne 0 ]; then
        # shellcheck disable=SC2034
        PROCESSOR_FAILURE="$rc"
    fi
    return "$rc"
}

function processor_require_file() {
    local path="$1"
    local label="${2:-Processor output}"

    if [ ! -f "$path" ]; then
        status_error "$label was not created: $path"
        # shellcheck disable=SC2034
        PROCESSOR_FAILURE=1
        return 1
    fi
    return 0
}

function processor_bootstrap() {
    if [[ "$STATICCONFIG" = true ]]; then
        # shellcheck source=/dev/null
        source "$CONFIGFILE"
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
            if campaign_path_preserved "$path"; then
                continue
            fi
            rm -f -- "$path" 2>/dev/null || true
        fi
    done
}

function campaign_path_preserved() {
    local path="$1"
    local preserved

    if [ "${CAMPAIGN_MODE:-}" != 'execute' ]; then
        return 1
    fi
    for preserved in "${CAMPAIGN_PRESERVED_PATHS[@]:-}"; do
        if [ "$path" = "$preserved" ]; then
            return 0
        fi
    done
    return 1
}

function processor_interrupt() {
    local interrupt_rc=130
    local preserve_rc=0

    if [ "${CAMPAIGN_MODE:-}" = 'execute' ] && [ "${CAMPAIGN_ACTIVE_COMMAND_INDEX:--1}" -ge 0 ]; then
        if ! campaign_command_preserve_inputs "$@"; then
            preserve_rc=1
        fi
    fi
    if [ -n "${CAMPAIGN_INTERRUPT_MARKER:-}" ]; then
        if ! : >"$CAMPAIGN_INTERRUPT_MARKER"; then
            preserve_rc=1
        fi
    fi
    if [ "$preserve_rc" -eq 0 ]; then
        processor_cleanup "$@"
        exit "$interrupt_rc"
    fi
    status_error "Unable to preserve interrupted campaign inputs; cleanup was skipped."
    exit 1
}

function dry_run_enabled() {
    [ "$DRYRUN" = ' ' ]
}

function dryrun_note() {
    printf '[DRY-RUN] %s\n' "$*"
}

function dryrun_tempfile() {
    local tag="${1:-tmp}"
    local campaign_key
    local campaign_id
    local temp_index

    if [ "${CAMPAIGN_MODE:-}" = 'plan' ] || [ "${CAMPAIGN_MODE:-}" = 'execute' ]; then
        campaign_key="${CAMPAIGN_MANIFEST:-${CAMPAIGN_OUTPUT:-}}"
        if [ -n "$campaign_key" ] && [ -n "${CAMPAIGN_CURRENT_STEP:-}" ]; then
            temp_index="${CAMPAIGN_TEMP_INDEX:-0}"
            CAMPAIGN_TEMP_INDEX=$((temp_index + 1))
            campaign_id=$(printf '%s' "$campaign_key" | cksum | awk '{print $1}')
            printf '/tmp/hash-cracker-campaign-%s-%s-%s-%s' \
                "$campaign_id" "$CAMPAIGN_CURRENT_STEP" "$tag" "$temp_index"
            return 0
        fi
    fi
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
    local path

    if [ -n "${SESSION_POT_UNIQUE_CACHE:-}" ]; then
        rm -f -- "$SESSION_POT_UNIQUE_CACHE" 2>/dev/null || true
    fi
    for path in "${CAMPAIGN_EPHEMERAL_FILES[@]:-}"; do
        if [ -n "$path" ]; then
            rm -f -- "$path" 2>/dev/null || true
        fi
    done
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

    new_unique_lines=$(LC_ALL=C comm -13 "$SESSION_POT_UNIQUE_CACHE" "$tmp_delta" | wc -l | tr -d '[:space:]')
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
        if ! mkdir -p "$parent"; then
            status_error "Unable to create output directory: $parent"
            return 1
        fi
    fi
    return 0
}

function stats_export_scope() {
    local scope="${STATSEXPORT_SCOPE:-latest}"
    case "$scope" in
        latest | all) printf '%s' "$scope" ;;
        *) printf 'latest' ;;
    esac
}

function export_session_stats_history_json() {
    local logs_dir="${SESSION_LOG_DIR:-logs}"
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

    if ! ensure_parent_dir "$out_path"; then
        return 1
    fi

    if [ "${SESSION_LOG_DISABLED:-0}" = '1' ] || [ "${SESSION_LOG_AVAILABLE:-0}" -ne 1 ]; then
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

    if [ -d "$out_path" ]; then
        status_error "Unable to replace stats export: $out_path"
        return 1
    fi

    tmp_path="${out_path}.tmp.$$"

    if ! cat >"$tmp_path" <<EOF; then
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
        rm -f -- "$tmp_path"
        status_error "Unable to write stats export: $out_path"
        return 1
    fi

    if ! mv -- "$tmp_path" "$out_path"; then
        rm -f -- "$tmp_path"
        status_error "Unable to replace stats export: $out_path"
        return 1
    fi
    return 0
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
    local logs_dir="${SESSION_LOG_DIR:-logs}"
    local log_dir
    local session_stamp
    local keep_count

    SESSION_LOG_AVAILABLE=0

    if [ "${SESSION_LOG_DISABLED:-0}" = '1' ]; then
        SESSION_STATS_LOGFILE=''
        return 0
    fi

    keep_count=$(session_log_keep_count)

    if [ -n "${SESSION_STATS_LOGFILE:-}" ]; then
        log_dir=$(dirname "$SESSION_STATS_LOGFILE")
        if [ -n "$log_dir" ] && [ "$log_dir" != "." ]; then
            if ! mkdir -p "$log_dir"; then
                status_bad "Unable to create session log directory: $log_dir"
                SESSION_STATS_LOGFILE=''
                return 1
            fi
        fi
        SESSION_LOG_AVAILABLE=1
        return 0
    fi

    session_stamp=$(date '+%Y%m%d-%H%M%S')
    SESSION_STATS_LOGFILE="$logs_dir/session-${session_stamp}-${BASHPID}.log"

    if ! mkdir -p "$logs_dir"; then
        status_bad "Unable to create session log directory: $logs_dir"
        SESSION_STATS_LOGFILE=''
        return 1
    fi
    SESSION_LOG_AVAILABLE=1
    prune_session_logs "$logs_dir" "$keep_count"
    if ! ln -sfn "$(basename "$SESSION_STATS_LOGFILE")" "$logs_dir/latest.log"; then
        status_bad "Unable to update latest session log link: $logs_dir/latest.log"
    fi
    return 0
}

function log_session_stats_line() {
    local line="$1"
    if [ -z "${SESSION_STATS_LOGFILE:-}" ]; then
        return 0
    fi

    if ! printf '[%s] %s\n' "$(timestamp_now)" "$line" >>"$SESSION_STATS_LOGFILE"; then
        status_bad "Unable to append session stats log: $SESSION_STATS_LOGFILE"
        SESSION_LOG_AVAILABLE=0
        return 1
    fi
    return 0
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
    elif [ "${SESSION_LOG_AVAILABLE:-0}" -ne 1 ]; then
        log_state="unavailable"
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
            if [ "$delta_lines" -gt 0 ]; then
                update_unique_plaintexts_incremental "$delta_lines"
            elif [ "$SESSION_POT_BYTES_CUR" -gt "$SESSION_POT_BYTES_LAST" ]; then
                stats_debug_note "Stats refresh mode: full recount (byte-only potfile growth)"
                rebuild_unique_plaintext_cache
            fi
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
    local job_text
    local start_time
    local end_time
    local duration

    refresh_session_stats
    session_stats_line=$(build_session_stats_line)
    log_session_stats_line "$session_stats_line"
    if ! export_session_stats_json; then
        return 1
    fi

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

    if ! job_text="$(job_text_by_id "$selected")"; then
        status_error "Invalid job selection for --job: $selected"
        status_heading "Use --list-jobs to see available options."
        return 1
    fi

    start_time=$(current_epoch_seconds)
    run_processor "$selected"
    rc=$?
    end_time=$(current_epoch_seconds)
    duration=$(format_duration "$((end_time - start_time))")
    print_job_timing_result "$selected" "$job_text" "$rc" "$duration"

    refresh_session_stats
    session_stats_line=$(build_session_stats_line)
    log_session_stats_line "$session_stats_line"
    if ! export_session_stats_json; then
        if [ "$rc" -eq 0 ]; then
            rc=1
        fi
    fi

    return $rc
}

function run_preset_mode() {
    local preset_name="$1"
    local preset_jobs
    local job_id
    local job_text
    local rc
    local session_stats_line
    local preset_start_time
    local preset_end_time
    local job_start_time
    local job_end_time
    local duration
    local rows=""
    local completed=0
    local failed=0
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
    if ! export_session_stats_json; then
        return 1
    fi

    status_heading "Running preset '$preset_name' (jobs: $preset_jobs)"
    preset_start_time=$(current_epoch_seconds)
    for job_id in "${preset_job_ids[@]}"; do
        job_text="$(job_text_by_id "$job_id")"
        status_heading "Preset '$preset_name': running job $job_id ($job_text)"

        if ! check_job_dependencies "$job_id"; then
            status_error "Preset '$preset_name' failed before job $job_id ($job_text): missing dependency."
            failed=$((failed + 1))
            rows="${rows}${job_id}|${job_text}|failed|1|00:00:00"$'\n'
            preset_end_time=$(current_epoch_seconds)
            duration=$(format_duration "$((preset_end_time - preset_start_time))")
            print_preset_summary "$preset_name" "${#preset_job_ids[@]}" "$completed" "$failed" "$duration" "$rows"
            return 1
        fi

        job_start_time=$(current_epoch_seconds)
        run_processor "$job_id"
        rc=$?
        job_end_time=$(current_epoch_seconds)
        duration=$(format_duration "$((job_end_time - job_start_time))")
        if [ "$rc" -ne 0 ]; then
            status_error "Preset '$preset_name' failed at job $job_id ($job_text)."
            failed=$((failed + 1))
            rows="${rows}${job_id}|${job_text}|failed|${rc}|${duration}"$'\n'
            preset_end_time=$(current_epoch_seconds)
            duration=$(format_duration "$((preset_end_time - preset_start_time))")
            print_preset_summary "$preset_name" "${#preset_job_ids[@]}" "$completed" "$failed" "$duration" "$rows"
            return "$rc"
        fi
        completed=$((completed + 1))
        rows="${rows}${job_id}|${job_text}|ok|${rc}|${duration}"$'\n'

        refresh_session_stats
        session_stats_line=$(build_session_stats_line)
        log_session_stats_line "$session_stats_line"
        if ! export_session_stats_json; then
            return 1
        fi
    done

    preset_end_time=$(current_epoch_seconds)
    duration=$(format_duration "$((preset_end_time - preset_start_time))")
    print_preset_summary "$preset_name" "${#preset_job_ids[@]}" "$completed" "$failed" "$duration" "$rows"
    status_ok "Preset '$preset_name' completed."
    return 0
}

function menu() {
    local option_id option_text processor
    local session_stats_line
    local job_text
    local start_time
    local end_time
    local duration
    local rc

    while true; do
        refresh_session_stats
        echo -e "\n0. Exit"
        print_job_list
        echo
        session_stats_line=$(build_session_stats_line)
        log_session_stats_line "$session_stats_line"
        if ! export_session_stats_json; then
            return 1
        fi

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

        if ! job_text="$(job_text_by_id "$START")"; then
            echo -e "Not valid, try again\n"
            continue
        fi

        if ! check_job_dependencies "$START"; then
            echo
            continue
        fi

        start_time=$(current_epoch_seconds)
        run_processor "$START"
        rc=$?
        end_time=$(current_epoch_seconds)
        duration=$(format_duration "$((end_time - start_time))")
        print_job_timing_result "$START" "$job_text" "$rc" "$duration"

        if [ "$rc" -ne 0 ]; then
            echo -e "Not valid, try again\n"
            continue
        fi

        source scripts/parameters.sh "$@"
    done
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    return 0
fi

run_early_list_mode "$@"
init_colors
trap cleanup_session_state EXIT
source scripts/parameters.sh "$@"

if [ -n "$CAMPAIGN_PLAN" ]; then
    run_campaign_plan "$CAMPAIGN_PLAN" "$CAMPAIGN_OUTPUT"
    exit $?
fi

status_heading "Preparing session stats (counting potfile and input hashes)..."
init_session_stats

if [ -n "$CAMPAIGN_EXECUTE" ] || [ -n "$CAMPAIGN_RESUME" ]; then
    if [ -n "$CAMPAIGN_RESUME" ]; then
        run_campaign_execute "$CAMPAIGN_RESUME" 'Resuming'
    else
        run_campaign_execute "$CAMPAIGN_EXECUTE" 'Executing'
    fi
    exit $?
fi

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
