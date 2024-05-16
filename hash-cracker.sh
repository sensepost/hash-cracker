#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

function hash-cracker () {
    echo -e "\nhash-cracker v4.2 by crypt0rr (https://github.com/crypt0rr)"
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
    echo "19. Digit remover"
    echo "20. Stacker"
    echo -e "21. Custom brute force\n"

    read -p "Please enter job number or type exit: " START
    if [[ "$START" = "0" ]] || [[ "$START" = "exit" ]]; then
        echo "Bye..."; exit 1
    elif [[ $START = '1' ]]; then
        source scripts/processors/1-bruteforce.sh
    elif [[ $START = '2' ]]; then
        source scripts/processors/2-light.sh
    elif [[ $START = '3' ]]; then
        source scripts/processors/3-heavy.sh
    elif [[ $START = '4' ]]; then
        source scripts/processors/4-word.sh
    elif [[ $START = '5' ]]; then
        source scripts/processors/5-word-bruteforce.sh
    elif [[ $START = '6' ]]; then
        source scripts/processors/6-hybrid.sh
    elif [[ $START = '7' ]]; then
        source scripts/processors/7-toggle.sh
    elif [[ $START = '8' ]]; then
        source scripts/processors/8-combinator.sh
    elif [[ $START = '9' ]]; then
        source scripts/processors/9-iterate.sh
    elif [[ $START = '10' ]]; then
        source scripts/processors/10-prefixsuffix.sh
    elif [[ $START = '11' ]]; then
        source scripts/processors/11-commonsubstring.sh
    elif [[ $START = '12' ]]; then
        source scripts/processors/12-pack-rule.sh
    elif [[ $START = '13' ]]; then
        source scripts/processors/13-pack-mask.sh
    elif [[ $START = '14' ]]; then
        source scripts/processors/14-fingerprint.sh
    elif [[ $START = '15' ]]; then
        source scripts/processors/15-multiple-wordlists.sh
    elif [[ $START = '16' ]]; then
        source scripts/processors/16-usernameaspassword.sh
    elif [[ $START = '17' ]]; then
        source scripts/processors/17-markov-generator.sh
    elif [[ $START = '18' ]]; then
        source scripts/processors/18-cewl.sh
    elif [[ $START = '19' ]]; then
        source scripts/processors/19-digitremover.sh
    elif [[ $START = '20' ]]; then
        source scripts/processors/20-stacker.sh
    elif [[ $START = '21' ]]; then
        source scripts/processors/21-custom-brute-force.sh
    else
        echo -e "Not valid, try again\n"; menu
    fi
    source scripts/parameters.sh "$@"
    menu
}

source scripts/parameters.sh "$@"
menu