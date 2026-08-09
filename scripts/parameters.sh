#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

if [ "$1" == '-h' ] || [ "$1" == '--help' ]; then
    echo -e "Note: flags are optional, by default hash-cracker will run with optimized kernels enabled and perform loopback actions."
    echo -e "\nUsage: ./hash-cracker.sh [FLAG]"
    echo -e "\nFlags:"
    echo -e "\t-l / --no-loopback\n\t\t Disable loopback functionality"
    echo -e "\t-n / --no-limit\n\t\t Disable the use of optimized kernels (un-limits password length)"
    echo -e "\t--hwmon-enable\n\t\t Enable hashcat to do hardware monitoring"
    echo -e "\t-m / --module-info\n\t\t Display information around modules/options"
    echo -e "\t-s [hash-name] / --search [hash-name]\n\t\t Will search local DB for hash module. E.g. '-s ntlm'"
    echo -e "\t-d / --disable-cracked\n\t\t Will stop output cracked hashes directly on screen."
    echo -e "\t--dry-run\n\t\t Print hashcat commands without executing them"
    echo -e "\t--no-session-log\n\t\t Disable session stats logging to file"
    echo -e "\t--session-log-keep [N]\n\t\t Keep last N auto-created session logs in logs/ (default: 0, no pruning)"
    echo -e "\t--stats-debug\n\t\t Print how session stats are refreshed (incremental vs full recount)"
    echo -e "\t--stats-export [PATH]\n\t\t Export machine-readable session stats JSON to PATH"
    echo -e "\t--stats-export-scope [latest|all]\n\t\t Export latest snapshot only or all entries from logs (default: latest)"
    echo -e "\t--job [ID]\n\t\t Run one menu option non-interactively (supports 1-22 and 99)"
    echo -e "\t--list-jobs\n\t\t Print available job IDs and exit"
    echo -e "\t--preset [NAME]\n\t\t Run a built-in non-interactive job preset"
    echo -e "\t--list-presets\n\t\t Print available preset names and exit"
    echo -e "\t--plan [PRESET|JOB] --output PATH\n\t\t Create a reproducible campaign plan without executing Hashcat"
    echo -e "\t--execute PATH\n\t\t Execute a campaign manifest from its first incomplete step"
    echo -e "\t--resume PATH\n\t\t Resume an interrupted or failed campaign manifest"
    echo -e "\t--self-test / --doctor\n\t\t Run non-interactive dependency and configuration checks, then exit"
    exit 1
elif [ "$1" == '-m' ] || [ "$1" == '--module-info' ]; then
    echo "Information about the modules"
    echo "1. Brute force: A commonly known set of brute force tasks"
    echo "2. Light rules: A wordlist + a set of non-heavy rules is ran agains the hashlist"
    echo "3. Heavy rules: A wordlist + a set of heavy rules is ran agains the hashlist (take a cup or 10 of coffee)"
    echo "4. Enter your own word, for example a company name to change around with rules"
    echo "5. Enter your own word, for example a company name to brute force before and after"
    echo "6. Hybrid: Wordlist + bruteforce random combined"
    echo "7. Toggle case: Will toggle chars randomly based on toggle rules and add couple simple rules to create variations"
    echo "8. Combinator: Will combine two input wordlists to create new passwords - first list given is the 'left' side, second list 'right' side"
    echo "9. Iterate results: Iterate gathered results from a previous performed job, advise to run this multiple times after completing other tasks"
    echo "10. Prefix suffix: Will take the already cracked hashes, take the prefix and suffix and put them together in variations"
    echo "11. Common substring: Will take the common substrings out of the already cracked hashes and create new variations"
    echo "12. PACK rulegen will take the already cracked plaintext passwords and create a new rule, the rule is then used with the wordlist of your choise. Requires pyenchant (python3 -m pip install pyenchant==3.3.0)"
    echo "13. PACK maskgen will craft pattern-based mask attacks."
    echo "14. Fingerprint attack, disassembling cracked plaintext passwords into fragments. Default max fragment length is 8 (set FINGERPRINT_SEGMENT_MAX to tune)."
    echo "15. Takes all wordlists in a folder, for example the 'wordlists'. Goes thru them plaintext and then again with OneRuleToRuleThemAll."
    echo "16. Usernames will be stripped out the NTDS dump you provide and used as input list for cracking hashes."
    echo "17. Markov-chain password generator will generate new password sets based on Time-Space Tradeoff - https://www.cs.cornell.edu/~shmat/shmat_ccs05pwd.pdf"
    echo "18. Custom Word List Generator - CeWL - Spiders a given URL and creates a custom wordlist."
    echo "19. Will take the potfile, strip the digits from the cleartexts and perform a hybrid attack accordingly, thereafter some rules to finish the job."
    echo "20. Using the stacking58.rule with a rule stacked on top of it to create even more variation on the randomness."
    echo "21. You can specify a lenght you want to brute-force, this will use the '?a' setting so the full charspace. Incremental approach is optional."
    exit 1
elif [ "$1" == '-s' ] || [ "$1" == '--search' ]; then
    TYPELIST="scripts/extensions/hashtypes"
    if [ -z "$2" ]; then
        echo "Please provide a search value, e.g. '--search ntlm'"
        exit 1
    fi
    grep -i -- "$2" "$TYPELIST" | sort
    exit 1
fi

# Dynamic Parameters
CAMPAIGN_PLAN=''
CAMPAIGN_OUTPUT=''
CAMPAIGN_EXECUTE=''
CAMPAIGN_RESUME=''
# shellcheck disable=SC2034
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n | --no-limit) KERNEL=' ' ;;
        -l | --no-loopback) LOOPBACK=' ' ;;
        --hwmon-enable) HWMON=' ' ;;
        -d | --disable-cracked) SHOWCRACKED=' ' ;;
        --dry-run) DRYRUN=' ' ;;
        --no-session-log) SESSION_LOG_DISABLED='1' ;;
        --stats-debug) STATSDEBUG=' ' ;;
        --stats-export)
            if [ -z "${2:-}" ]; then
                status_error "Missing value for --stats-export. Provide a file path."
                exit 1
            fi
            STATSEXPORT="$2"
            shift
            ;;
        --stats-export=*)
            STATSEXPORT="${1#*=}"
            if [ -z "$STATSEXPORT" ]; then
                status_error "Missing value for --stats-export. Provide a file path."
                exit 1
            fi
            ;;
        --stats-export-scope)
            case "${2:-}" in
                latest | all)
                    STATSEXPORT_SCOPE="$2"
                    shift
                    ;;
                *)
                    status_error "Invalid value for --stats-export-scope. Use 'latest' or 'all'."
                    exit 1
                    ;;
            esac
            ;;
        --stats-export-scope=*)
            STATSEXPORT_SCOPE="${1#*=}"
            case "$STATSEXPORT_SCOPE" in
                latest | all) ;;
                *)
                    status_error "Invalid value for --stats-export-scope. Use 'latest' or 'all'."
                    exit 1
                    ;;
            esac
            ;;
        --job)
            case "${2:-}" in
                '' | *[!0-9]*)
                    status_error "Invalid value for --job. Expected a numeric job ID."
                    exit 1
                    ;;
                *)
                    JOBMODE="$2"
                    shift
                    ;;
            esac
            ;;
        --job=*)
            JOBMODE="${1#*=}"
            case "$JOBMODE" in
                '' | *[!0-9]*)
                    status_error "Invalid value for --job. Expected a numeric job ID."
                    exit 1
                    ;;
            esac
            ;;
        --list-jobs) JOBLIST=' ' ;;
        --preset)
            if [ -z "${2:-}" ]; then
                status_error "Missing value for --preset. Provide a preset name."
                exit 1
            fi
            PRESETMODE="$2"
            shift
            ;;
        --preset=*)
            PRESETMODE="${1#*=}"
            if [ -z "$PRESETMODE" ]; then
                status_error "Missing value for --preset. Provide a preset name."
                exit 1
            fi
            ;;
        --list-presets) PRESETLIST=' ' ;;
        --plan)
            if [ -z "${2:-}" ]; then
                status_error "Missing value for --plan. Provide a preset name or job ID."
                exit 1
            fi
            CAMPAIGN_PLAN="$2"
            shift
            ;;
        --plan=*)
            CAMPAIGN_PLAN="${1#*=}"
            if [ -z "$CAMPAIGN_PLAN" ]; then
                status_error "Missing value for --plan. Provide a preset name or job ID."
                exit 1
            fi
            ;;
        --output)
            if [ -z "${2:-}" ]; then
                status_error "Missing value for --output. Provide a campaign manifest path."
                exit 1
            fi
            CAMPAIGN_OUTPUT="$2"
            shift
            ;;
        --output=*)
            CAMPAIGN_OUTPUT="${1#*=}"
            if [ -z "$CAMPAIGN_OUTPUT" ]; then
                status_error "Missing value for --output. Provide a campaign manifest path."
                exit 1
            fi
            ;;
        --execute)
            if [ -z "${2:-}" ]; then
                status_error "Missing value for --execute. Provide a campaign manifest path."
                exit 1
            fi
            CAMPAIGN_EXECUTE="$2"
            shift
            ;;
        --execute=*)
            CAMPAIGN_EXECUTE="${1#*=}"
            if [ -z "$CAMPAIGN_EXECUTE" ]; then
                status_error "Missing value for --execute. Provide a campaign manifest path."
                exit 1
            fi
            ;;
        --resume)
            if [ -z "${2:-}" ]; then
                status_error "Missing value for --resume. Provide a campaign manifest path."
                exit 1
            fi
            CAMPAIGN_RESUME="$2"
            shift
            ;;
        --resume=*)
            CAMPAIGN_RESUME="${1#*=}"
            if [ -z "$CAMPAIGN_RESUME" ]; then
                status_error "Missing value for --resume. Provide a campaign manifest path."
                exit 1
            fi
            ;;
        --session-log-keep)
            case "${2:-}" in
                '' | *[!0-9]*)
                    status_error "Invalid value for --session-log-keep. Expected a non-negative integer."
                    exit 1
                    ;;
                *)
                    SESSION_LOG_KEEP="$2"
                    shift
                    ;;
            esac
            ;;
        --session-log-keep=*)
            SESSION_LOG_KEEP="${1#*=}"
            case "$SESSION_LOG_KEEP" in
                '' | *[!0-9]*)
                    status_error "Invalid value for --session-log-keep. Expected a non-negative integer."
                    exit 1
                    ;;
            esac
            ;;
        --self-test | --doctor) SELFTEST=' ' ;;
        *)
            status_error "Unknown parameter passed: $1"
            exit 1
            ;;
    esac
    shift
done

if [ -n "$CAMPAIGN_PLAN" ] && [ -z "$CAMPAIGN_OUTPUT" ]; then
    status_error "Campaign plans require --output PATH."
    exit 1
fi
if [ -n "$CAMPAIGN_OUTPUT" ] && [ -z "$CAMPAIGN_PLAN" ]; then
    status_error "--output is only valid with --plan."
    exit 1
fi
if [ -n "$CAMPAIGN_EXECUTE" ] && [ -n "$CAMPAIGN_RESUME" ]; then
    status_error "Use either --execute or --resume, not both."
    exit 1
fi
if [ -n "$CAMPAIGN_PLAN" ] && { [ -n "$CAMPAIGN_EXECUTE" ] || [ -n "$CAMPAIGN_RESUME" ]; }; then
    status_error "Use either --plan or --execute/--resume, not both."
    exit 1
fi
if [ -n "$CAMPAIGN_PLAN" ] && { [ -n "${PRESETMODE:-}" ] || [ -n "${JOBMODE:-}" ]; }; then
    status_error "Use either --plan or --preset/--job, not both."
    exit 1
fi
if [ -n "$CAMPAIGN_EXECUTE" ] && { [ -n "${PRESETMODE:-}" ] || [ -n "${JOBMODE:-}" ]; }; then
    status_error "Use either --execute/--resume or --preset/--job, not both."
    exit 1
fi
if [ -n "$CAMPAIGN_RESUME" ] && { [ -n "${PRESETMODE:-}" ] || [ -n "${JOBMODE:-}" ]; }; then
    status_error "Use either --execute/--resume or --preset/--job, not both."
    exit 1
fi
if [ -n "$CAMPAIGN_PLAN" ]; then
    DRYRUN=' '
fi

CONFIGFILE="${HASH_CRACKER_CONFIG:-hash-cracker.conf}"
# shellcheck disable=SC2034
STATICCONFIG=true
COUNTER=0

if [ ! -f "$CONFIGFILE" ]; then
    status_error "Missing required configuration file: $CONFIGFILE"
    exit 1
fi

# shellcheck source=/dev/null
source "$CONFIGFILE"

REQUIRED_CONFIG_VARS=(HASHCAT HASHTYPE HASHLIST POTFILE WORDLIST WORDLIST2)
for REQUIRED_CONFIG_VAR in "${REQUIRED_CONFIG_VARS[@]}"; do
    if [ -z "${!REQUIRED_CONFIG_VAR}" ]; then
        status_error "Missing required setting '$REQUIRED_CONFIG_VAR' in $CONFIGFILE"
        exit 1
    fi
done

# Use a single execution wrapper for every hashcat invocation in processors.
# Processors call "$HASHCAT ...", so we point HASHCAT to this function name.
HASHCAT_BIN="$HASHCAT"
run_hashcat() {
    local command_index=-1
    local cmd_line
    local command_start_time
    local duration
    local rc
    local finish_rc
    local -a command_args=("$@")

    if [ "${CAMPAIGN_MODE:-}" = 'execute' ]; then
        # shellcheck disable=SC2034
        CAMPAIGN_ACTIVE_COMMAND_INDEX=-1
        command_index="$CAMPAIGN_COMMAND_INDEX"
        if ! campaign_command_start; then
            # shellcheck disable=SC2034
            HASHCAT_FAILURE=1
            return 1
        fi
        if [ "$CAMPAIGN_COMMAND_STATE" = 'completed' ]; then
            return 0
        fi
        CAMPAIGN_ACTIVE_COMMAND_INDEX="$command_index"
        if [ -n "$CAMPAIGN_COMMAND_ARGS_FILE" ]; then
            command_args=()
            while IFS= read -r -d '' restored_arg; do
                command_args+=("$restored_arg")
            done <"$CAMPAIGN_COMMAND_ARGS_FILE"
            if [ "${command_args[0]:-}" != "$HASHCAT_BIN" ]; then
                # shellcheck disable=SC2034
                HASHCAT_FAILURE=1
                status_error "Campaign command checkpoint has a different Hashcat executable."
                return 1
            fi
            command_args=("${command_args[@]:1}")
            if [ "$CAMPAIGN_RESTORE" -eq 1 ]; then
                local has_restore=0
                local restored_arg
                for restored_arg in "${command_args[@]}"; do
                    if [ "$restored_arg" = '--restore' ]; then
                        has_restore=1
                        break
                    fi
                done
                if [ "$has_restore" -eq 0 ]; then
                    command_args+=("--restore")
                fi
            fi
        else
            command_args+=("--session=$CAMPAIGN_SESSION_NAME")
            command_args+=("--restore-file-path=$CAMPAIGN_RESTORE_FILE")
            if [ "$CAMPAIGN_RESTORE" -eq 1 ]; then
                command_args+=("--restore")
            fi
        fi
    fi

    printf -v cmd_line '%q ' "$HASHCAT_BIN" "${command_args[@]}"
    if [ "$command_index" -ge 0 ] && ! campaign_command_record "$command_index" "${cmd_line% }"; then
        # shellcheck disable=SC2034
        HASHCAT_FAILURE=1
        return 1
    fi
    if [ -n "${CAMPAIGN_COMMAND_FILE:-}" ]; then
        campaign_record_command "${cmd_line% }"
    fi

    if [ "$DRYRUN" = ' ' ]; then
        printf '[DRY-RUN] '
        printf '%s\n' "$cmd_line"
        return 0
    fi

    command_start_time=$(current_epoch_seconds)
    "$HASHCAT_BIN" "${command_args[@]}"
    rc=$?
    duration=$(($(current_epoch_seconds) - command_start_time))

    if [ "$command_index" -ge 0 ]; then
        campaign_command_finish "$command_index" "$rc" "$duration"
        finish_rc=$?
        if [ "$finish_rc" -ne 0 ] && [ "$rc" -eq 0 ]; then
            rc=1
        fi
        # shellcheck disable=SC2034
        CAMPAIGN_ACTIVE_COMMAND_INDEX=-1
    fi

    if [ $rc -ne 0 ]; then
        # shellcheck disable=SC2034
        HASHCAT_FAILURE="$rc"
        echo "[hash-cracker] hashcat command failed with exit code $rc" >&2
    fi
    return $rc
}
HASHCAT='run_hashcat'

HASHTYPE_DISPLAY=$(
    awk -F'\\|' -v mode="$HASHTYPE" '
        {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
            if ($1 == mode) {
                print $1 " " $2
                exit
            }
        }
    ' scripts/extensions/hashtypes
)

if [ -n "$HASHTYPE_DISPLAY" ]; then
    HASHTYPE_MODE="${HASHTYPE_DISPLAY%% *}"
    HASHTYPE_NAME="${HASHTYPE_DISPLAY#* }"
    if [ -n "$HASHTYPE_NAME" ] && [ "$HASHTYPE_NAME" != "$HASHTYPE_MODE" ]; then
        BANNER_STATUS_VALUE="cracking $HASHTYPE_NAME ($HASHTYPE_MODE) / hashlist $HASHLIST"
    else
        BANNER_STATUS_VALUE="cracking mode $HASHTYPE / hashlist $HASHLIST"
    fi
else
    BANNER_STATUS_VALUE="cracking mode $HASHTYPE / hashlist $HASHLIST"
fi
# shellcheck disable=SC2034
BANNER_STATUS="$BANNER_STATUS_VALUE"

hash-cracker

# Logic
echo -e "\nMandatory modules:"
if [ "$DRYRUN" = ' ' ]; then
    status_ok "Hashcat executable check skipped (dry-run mode)"
elif ! [ -x "$(command -v "$HASHCAT_BIN")" ]; then
    status_bad "Hashcat is not available/executable"
    ((COUNTER = COUNTER + 1))
else
    status_ok "Hashcat is executable"
fi
if test -f "$POTFILE"; then
    status_ok "Potfile $POTFILE present"
elif [ "$DRYRUN" = ' ' ]; then
    status_bad "Potfile not present, dry-run would create $POTFILE"
else
    status_bad "Potfile not present, will create $POTFILE"
    touch "$POTFILE"
fi
if [ "$COUNTER" -gt 0 ]; then
    status_error "Not all mandatory requirements are met. Please fix and try again."
    exit 1
fi

# Apple macOS vs Linux
UNAMEOUT="$(uname -s)"
case "${UNAMEOUT}" in
    Linux*) MACHINE=Linux ;;
    Darwin*) MACHINE=Mac ;;
    *) MACHINE="UNKNOWN:${UNAMEOUT}" ;;
esac

if [ "$MACHINE" == "Mac" ]; then
    source scripts/mac.sh
elif [ "$MACHINE" == "Linux" ]; then
    source scripts/linux.sh
else
    status_error "PLEASE OPEN ISSUE with output of 'uname -s'. Fallback to Linux"
    source scripts/linux.sh
fi

echo -e "\nVariable Parameters:"
if [ "$KERNEL" = ' ' ]; then
    status_bad "Optimised kernels disabled"
else
    status_ok "Optimised kernels enabled"
    KERNEL='-O'
fi

if [ "$LOOPBACK" = ' ' ]; then
    status_bad "Loopback disabled"
else
    status_ok "Loopback enabled"
    LOOPBACK='--loopback'
fi

if [ "$HWMON" = ' ' ]; then
    status_ok "Hardware monitoring enabled"
else
    status_bad "Hardware monitoring disabled"
    HWMON='--hwmon-disable'
fi

if [ "$SHOWCRACKED" = ' ' ]; then
    status_bad "STDOUT cracked hashes disabled"
    SHOWCRACKED='-o /dev/null'
else
    status_ok "STDOUT cracked hashes enabled"
fi

if [ "$DRYRUN" = ' ' ]; then
    status_ok "Dry-run enabled (hashcat commands will be printed only)"
else
    status_bad "Dry-run disabled"
fi

if [ "${SESSION_LOG_DISABLED:-0}" = '1' ]; then
    status_bad "Session stats logging disabled"
else
    SESSION_LOG_KEEP_EFFECTIVE="${SESSION_LOG_KEEP:-0}"
    status_ok "Session stats logging enabled"
    if [ "$SESSION_LOG_KEEP_EFFECTIVE" -eq 0 ]; then
        if [ -z "${SESSION_LOG_KEEP+x}" ]; then
            status_ok "Session log retention: keeping all files (default)"
        else
            status_ok "Session log retention: keeping all files (pruning disabled)"
        fi
    else
        status_ok "Session log retention: keeping last $SESSION_LOG_KEEP_EFFECTIVE file(s)"
    fi
fi

if [ "$STATSDEBUG" = ' ' ]; then
    status_ok "Stats debug output enabled"
fi

if [ -n "${STATSEXPORT:-}" ]; then
    status_ok "Stats export enabled: $STATSEXPORT"
    status_ok "Stats export scope: ${STATSEXPORT_SCOPE:-latest}"
fi

if [ -n "${JOBMODE:-}" ]; then
    status_ok "Non-interactive job mode enabled: job $JOBMODE"
fi

if [ -n "${PRESETMODE:-}" ]; then
    status_ok "Preset mode enabled: $PRESETMODE"
fi

if [ -n "$CAMPAIGN_PLAN" ]; then
    status_ok "Campaign planning enabled: $CAMPAIGN_PLAN"
    status_ok "Campaign output: $CAMPAIGN_OUTPUT"
fi
if [ -n "$CAMPAIGN_EXECUTE" ]; then
    status_ok "Campaign execution enabled: $CAMPAIGN_EXECUTE"
fi
if [ -n "$CAMPAIGN_RESUME" ]; then
    status_ok "Campaign resume enabled: $CAMPAIGN_RESUME"
fi

echo -e "\nStatic parameters:"
status_ok "Potfile: $POTFILE"
status_ok "Hashlist: $HASHLIST"
if [ -n "$HASHTYPE_DISPLAY" ]; then
    status_ok "Hashtype: $HASHTYPE_DISPLAY"
else
    status_ok "Hashtype: $HASHTYPE"
fi
status_ok "Wordlist 1: $WORDLIST"
status_ok "Wordlist 2: $WORDLIST2"
