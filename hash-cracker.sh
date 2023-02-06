#!/bin/bash
# Copyright crypt0rr

function hash-cracker () {
    echo -e "Mandatory modules:"
    source scripts/mandatory-checks.sh
    echo -e "\nOptional modules:"
    source scripts/optional-checks.sh
    menu
}

function menu () {
    echo -e "\n0. Exit"
    echo "1. Brute force"
    echo "2. Light rules"
    echo "3. Heavy rules"
    echo "4. Enter specific word/name/company"
    echo "5. Enter specific word/name/company (brute force)"
    echo "6. Hybrid"
    echo "7. Toggle-case"
    echo "8. Combinator"
    echo "9. Iterate results"
    echo "10. Prefix suffix (advise: first run steps above)"
    echo "11. Common substring (advise: first run steps above)"
    echo "12. PACK rulegen"
    echo "13. PACK mask"
    echo "14. Fingerprint attack"
    echo "15. Directory of word lists plain and then with OneRuleToRuleThemAll"
    echo "16. Username iteration (only complete NTDS)"
    echo "17. Markov-chain passwords generator"
    echo "18. CeWL wordlist generator"
    echo -e "19. Digit remover + Hybrid\n"

    read -p "Please enter job number: " START
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
    elif [[ $START = '15' ]]; then
        source scripts/processors/multiple-wordlists.sh
    elif [[ $START = '16' ]]; then
        source scripts/processors/usernameaspassword.sh
    elif [[ $START = '17' ]]; then
        source scripts/processors/markov-generator.sh
    elif [[ $START = '18' ]]; then
        source scripts/processors/cewl.sh
    elif [[ $START = '19' ]]; then
        source scripts/processors/digitremover.sh
    else
        echo -e "Not valid, try again\n"; menu
    fi
    hash-cracker
}

echo -e "hash-cracker v3.3 by crypt0rr (https://github.com/crypt0rr)\n"

NOP=$1

if [ "$1" == '-h' ] || [ "$1" == '--help' ]; then
    echo -e "Note: flags are optional, by default hash-cracker will run with optimized kernels enabled."
    echo -e "\nUsage: ./hash-cracker [FLAG]"
    echo -e "\nFlags:"
    echo -e "\t-n / --no-limit\n\t\t Disable the use of optimized kernels (un-limits password length)"
    echo -e "\t-m / --module-info\n\t\t Display information around modules/options"
    echo -e "\t-s [hash-name] / --search [hash-name]\n\t\t Will search local DB for hash module. E.g. '-s ntlm'"
elif [ "$1" == '-m' ] || [ "$1" == '--module-info' ]; then
    bash scripts/showinfo.sh
elif [ "$1" == '-s' ] || [ "$1" == '--search' ]; then
    TYPELIST="scripts/extensions/hashtypes"
    grep -i $2 $TYPELIST | sort
else
    hash-cracker
fi