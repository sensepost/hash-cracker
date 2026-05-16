#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

function hash-cracker () {
    echo -e "\nhash-cracker v5.0 by crypt0rr (https://github.com/crypt0rr)"
}

function menu_entries () {
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

function run_processor () {
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

function menu () {
    local option_id option_text processor

    while true; do
        echo -e "\n0. Exit"
        while IFS='|' read -r option_id option_text processor; do
            echo "$option_id. $option_text"
        done < <(menu_entries)
        echo -e "\nCurrent setup: hashtype=${HASHTYPE_DISPLAY:-$HASHTYPE} hashlist=$HASHLIST"

        read -r -p "Select job [0-22] or type exit: " START
        START="${START#"${START%%[![:space:]]*}"}"
        START="${START%"${START##*[![:space:]]}"}"

        if [[ -z "$START" ]]; then
            continue
        fi

        case "$START" in
            0|exit|quit|q)
                echo "Bye..."
                exit 0
                ;;
        esac

        if ! run_processor "$START"; then
            echo -e "Not valid, try again\n"
            continue
        fi

        source scripts/parameters.sh "$@"
    done
}

source scripts/parameters.sh "$@"
menu "$@"
