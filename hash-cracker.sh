#!/bin/bash
# Copyright crypt0rr

function main () {
    echo -e "hash-cracker \e[32mv2.4\e[0m by crypt0rr (https://github.com/crypt0rr)\n"
    echo -e "Checking if requirements are met:"
    source scripts/requirements.sh
    menu
}

function menu () {
    echo -e "\n0. Exit"
    echo "1. Brute force"
    echo "2. Light rules"
    echo "3. Heavy rules"
    echo "4. Enter specific word/name/company"
    echo "5. Enter specific word/name/company (bruteforce)"
    echo "6. Hybrid"
    echo "7. Toggle-case"
    echo "8. Combinator"
    echo "9. Iterate results"
    echo "10. Prefix suffix (advise: first run steps above)"
    echo "11. Common substring (advise: first run steps above)"
    echo "12. PACK rulegen (read option 99)"
    echo "13. PACK mask (read option 99)"
    echo "14. Fingerprint attack"
    echo -e "99. Show info about modules\n"

    read -p "Please enter number OR type 'search' to find hashtypes: " START
    if [[ "$START" = "0" ]] || [[ "$START" = "exit" ]]; then
        echo "Bye..."; exit 1
    elif [[ $START = '1' ]]; then
        source scripts/processors/bruteforce.sh
    elif [[ $START = '2' ]]; then
        source scripts/processors/light.sh
    elif [[ $START = '3' ]]; then
        source scripts/processors/heavy.sh
    elif [[ $START = '4' ]]; then
        source scripts/processors/word.sh
    elif [[ $START = '5' ]]; then
        source scripts/processors/word-bruteforce.sh
    elif [[ $START = '6' ]]; then
        source scripts/processors/hybrid.sh
    elif [[ $START = '7' ]]; then
        source scripts/processors/toggle.sh
    elif [[ $START = '8' ]]; then
        source scripts/processors/combinator.sh
    elif [[ $START = '9' ]]; then
        source scripts/processors/iterate.sh
    elif [[ $START = '10' ]]; then
        source scripts/processors/prefixsuffix.sh
    elif [[ $START = '11' ]]; then
        source scripts/processors/commonsubstring.sh
    elif [[ $START = '12' ]]; then
        source scripts/processors/pack-rule.sh
    elif [[ $START = '13' ]]; then
        source scripts/processors/pack-mask.sh
    elif [[ $START = '14' ]]; then
        source scripts/processors/fingerprint.sh
    elif [[ $START = '99' ]]; then
        bash scripts/showinfo.sh
    elif [[ $START = 'search' ]]; then
        source scripts/extensions/search.sh
    else
        echo -e "\e[31mNot valid, try again\n\e[0m"; menu
    fi
    menu
}

main