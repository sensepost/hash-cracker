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

function hash-cracker() {
    local status_text
    local version_text
    local progress_text

    status_text="status: ${BANNER_STATUS:-cracking salted secrets}"
    version_text="v5.0"
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

function dependency_fail() {
    status_error "$1"
    printf '%b    Fix: %s%b\n' "$COLOR_RED" "$2" "$COLOR_RESET"
    return 1
}

function check_job_dependencies() {
    local selected="$1"
    local common_substr_bin
    local expander_bin
    local python_bin
    local statsgen
    local maskgen

    case "$selected" in
        10 | 11)
            common_substr_bin="${COMMON_SUBSTR_BIN:-scripts/extensions/common-substr-linux}"
            if [ ! -x "$common_substr_bin" ]; then
                dependency_fail \
                    "Option $selected requires '$common_substr_bin'." \
                    "install/build common-substr and make it executable (e.g. chmod +x '$common_substr_bin')."
                return 1
            fi
            ;;
        12)
            if [ "$MACHINE" == "Mac" ]; then
                dependency_fail \
                    "Option 12 (PACK rulegen) is unavailable on macOS in this tool." \
                    "run option 12 on Linux with python2 installed."
                return 1
            fi
            if ! command -v python2 >/dev/null 2>&1; then
                dependency_fail \
                    "Option 12 requires 'python2'." \
                    "install python2 and ensure 'python2' is in PATH."
                return 1
            fi
            if [ ! -f "scripts/extensions/pack-linux/rulegen.py" ]; then
                dependency_fail \
                    "Option 12 requires 'scripts/extensions/pack-linux/rulegen.py'." \
                    "restore the bundled PACK files in scripts/extensions/pack-linux/."
                return 1
            fi
            ;;
        13)
            if [ "$MACHINE" == "Mac" ]; then
                python_bin="python3"
                statsgen="scripts/extensions/pack-mac/statsgen.py"
                maskgen="scripts/extensions/pack-mac/maskgen.py"
            else
                python_bin="python2"
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
        14)
            expander_bin="${EXPANDER_BIN:-scripts/extensions/hashcat-utils-linux/bin/expander.bin}"
            if [ ! -x "$expander_bin" ]; then
                dependency_fail \
                    "Option 14 requires '$expander_bin'." \
                    "restore/build hashcat-utils expander and make it executable (chmod +x '$expander_bin')."
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

function menu() {
    local option_id option_text processor

    while true; do
        echo -e "\n0. Exit"
        while IFS='|' read -r option_id option_text processor; do
            echo "$option_id. $option_text"
        done < <(menu_entries)
        echo -e "\nCurrent setup: hashtype=${HASHTYPE_DISPLAY:-$HASHTYPE} hashlist=$HASHLIST"
        echo

        if [ "$DRYRUN" = ' ' ]; then
            read -r -p "Select job [0-22] or type exit [DRY-RUN MODE]: " START
        else
            read -r -p "Select job [0-22] or type exit: " START
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

init_colors
source scripts/parameters.sh "$@"

if [ "$SELFTEST" = ' ' ]; then
    run_self_test
    exit $?
fi

menu "$@"
