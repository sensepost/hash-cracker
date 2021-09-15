#!/bin/bash
# Copyright crypt0rr
# Credits to @singe for digits rules and https://github.com/sensepost/common-substr
HASHCAT="/usr/local/bin/hashcat"
d3ad0ne="rules/d3ad0ne.rule"
d3adhob0="rules/d3adhob0.rule"
digits1="rules/digits1.rule"
digits2="rules/digits2.rule"
digits3="rules/digits3.rule"
dive="rules/dive.rule"
fordyv1="rules/fordyv1.rule" # Credits to Fordy
generated2="rules/generated2.rule"
hob064="rules/hob064.rule"
leetspeak="rules/leetspeak.rule"
NSAKEYv2="rules/NSAKEY.v2.dive.rule"
ORTRTA="rules/OneRuleToRuleThemAll.rule"
OUTD="rules/OptimizedUpToDate.rule"
pantag="rules/pantagrule.popular.rule"
passwordpro="rules/passwordspro.rule"
rockyou30000="rules/rockyou-30000.rule"
techtrip2="rules/techtrip_2.rule"
toggles1="rules/toggles1.rule"
toggles2="rules/toggles2.rule"
tenKrules="rules/10krules.rule"
toprules2020="rules/toprules2020.rule"
williamsuper="rules/williamsuper.rule"
RULELIST_LIGHT=($rockyou30000 $ORTRTA $OUTD $passwordpro $d3ad0ne $d3adhob0 $generated2 $toprules2020 $digits1 $digits2 $hob064 $leetspeak $toggles1 $toggles2)
RULELIST_HEAVY=($tenKrules $NSAKEYv2 $fordyv1 $pantag $OUTD $techtrip2 $williamsuper $digits3 $dive)
RULELIST_SMALL=($digits1 $digits2 $hob064 $leetspeak $rockyou30000 $passwordpro $OUTD)

function requirement_checker () {
    if ! [ -x "$(command -v $HASHCAT)" ]; then
        echo -e '\e[31m[-]' Hashcat  'is not installed or not in path (/usr/local/bin/hashcat)\e[0m'; ((COUNTER=COUNTER + 1))
    else
        echo -e '\e[32m[+]' Hashcat 'is installed\e[0m'
    fi
    if [[ -x "common-substr" ]]; then
        echo -e '\e[32m[+]' 'common-substr is executable\e[0m'
    else
        echo -e '\e[31m[-]' 'common-substr is not executable or found\e[0m'; ((COUNTER=COUNTER + 1))
    fi
    if [ "$COUNTER" \> 0 ]; then
        echo -e "\n\e[31mNot all requirements met please fix and try again"; exit 1
    fi
}

function selector_hashtype () {
    read -p "Enter hashtype (number): " HASHTYPE
    if [ -z "${HASHTYPE##*[!0-9]*}" ]; then
        echo -e "\e[31mNot a valid hashtype number, try again (https://hashcat.net/wiki/doku.php?id=example_hashes)\e[0m"; selector_hashtype 
    else
        echo -e "\e[34mHashtype" `grep -w $HASHTYPE hashtypes` "selected.\e[0m"
    fi
}

function search_hashtype () {
    read -p "Enter search query: " QUERY
    echo -e "\e[34m" && grep -i $QUERY hashtypes
    echo -e "\e[0m" 
    main
}

function selector_hashlist () {
    read -e -p "Enter full path to hashlist: " HASHLIST
    if [ -f "$HASHLIST" ]; then
        echo "Hashlist" $HASHLIST "selected."
    else
        echo -e "\e[31mFile does not exist, try again\e[0m"; selector_hashlist
    fi
}

function selector_wordlist () {
    read -e -p "Enter full path to wordlist: " WORDLIST
    if [ -f "$WORDLIST" ]; then
        echo "Wordlist" $WORDLIST "selected."
    else
        echo -e "\e[31mFile does not exist, try again\e[0m"; selector_wordlist
    fi
    if [[ $START = '9' ]]; then
        read -e -p "Enter full path to second wordlist: " WORDLIST2
        if [ -f "$WORDLIST" ]; then
        echo "Wordlist" $WORDLIST "selected."
        else
            echo -e "\e[31mFile does not exist, try again\e[0m"; selector_wordlist
        fi
    fi
}

function default_processing_light () {
    $HASHCAT -O  --bitmap-max=24 -m$HASHTYPE $HASHLIST $WORDLIST
    for RULE in ${RULELIST_LIGHT[*]}; do
        $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST $WORDLIST -r $RULE --loopback
    done
    echo -e "\n\e[32mDefault processing with light rules done\e[0m\n"; main
}

function default_processing_heavy () {
    $HASHCAT -O  --bitmap-max=24 -m$HASHTYPE $HASHLIST $WORDLIST
    for RULE in ${RULELIST_HEAVY[*]}; do
        $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST $WORDLIST -r $RULE --loopback
    done
    echo -e "\n\e[32mDefault processing with heavy rules done\e[0m\n"; main
}

function bruteforce_processing () {
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST -a3 '?a?a?a?a?a' --increment
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST -a3 '?l?l?l?l?l?l?l?l' --increment
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST -a3 '?u?u?u?u?u?u?u?u' --increment
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST -a3 '?d?d?d?d?d?d?d?d?d?d' --increment
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST -a3 '?1?1?1?1?1?1?1' -1 '?l?d?u' --increment
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST -a3 '?1?1?1?1?2?2?2?2' -1 '?l?u' -2 '?d' --increment
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST -a3 '?1?1?1?1?2?2?2?2' -1 '?d' -2 '?l?u' --increment
    echo -e "\n\e[32mBrute force processing done\e[0m\n"; main
}

function iterate_processing () {
    for RULE in ${RULELIST_HEAVY[*]}; do
        $HASHCAT -O -m$HASHTYPE $HASHLIST --show > tmp_output && cat tmp_output | cut -d ':' -f2 | sort -u | tee tmp_pwonly &>/dev/null; rm tmp_output
        $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST tmp_pwonly -r $RULE --loopback
    done
    rm tmp_pwonly
    echo -e "\n\e[32mIteration processing done\e[0m\n"; main
}

function word_processing () {
    read -p "Enter a word (e.g. company name): " WORD
    echo $WORD > tmp_word
    for RULE in ${RULELIST_HEAVY[*]}; do
        $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST tmp_word -r $RULE --loopback
    done
    rm tmp_word
    echo -e "\n\e[32mWord processing done\e[0m\n"; main
}

function word_bruteforce () {
    read -p "Enter a word (e.g. company name): " WORD
    echo $WORD > tmp_word
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST -a6 tmp_word '?d?d?d?d?d?d?d?d' -i
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST -a6 tmp_word '?l?l?l?l?l?l' -i
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST -a7 '?d?d?d?d?d?d?d?d' tmp_word -i
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST -a7 '?l?l?l?l?l?l' tmp_word -i
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST -a6 tmp_word '?a?a?a?a' -i
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST -a7 '?a?a?a?a' tmp_word -i
    rm tmp_word
    echo -e "\n\e[32mWord processing done\e[0m\n"; main
}

function hybrid_processing () {
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST -a6 $WORDLIST -j c '?s?d?d?d?d' --increment
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST -a6 $WORDLIST -j c '?d?d?d?d?s' --increment
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST -a6 $WORDLIST -j c '?a?a' --increment
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST -a6 $WORDLIST '?s?d?d?d?d' --increment
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST -a6 $WORDLIST '?d?d?d?d?s' --increment
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST -a6 $WORDLIST '?a?a' --increment
    echo -e "\n\e[32mHybrid processing done\e[0m\n"; main
}

function toggle_processing () {
    for RULE in ${RULELIST_SMALL[*]}; do
        $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST $WORDLIST -r $toggles1 -r $RULE --loopback
        $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST $WORDLIST -r $toggles2 -r $RULE --loopback
    done
    echo -e "\n\e[32mToggle processing done\e[0m\n"; main
}

function combinator_processing () {
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST -a1 $WORDLIST $WORDLIST2
    echo -e "\n\e[32mCombinator processing done\e[0m\n"; main
}

function prefixsuffix_processing () {
    $HASHCAT -O -m$HASHTYPE $HASHLIST --show > tmp_prefixsuffix
    cat tmp_prefixsuffix | cut -d ':' -f2 | sort | tee tmp_passwords &>/dev/null && ./common-substr -n -p -f tmp_passwords > tmp_prefix && ./common-substr -n -s -f tmp_passwords > tmp_suffix && rm tmp_passwords tmp_prefixsuffix
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST -a1 tmp_prefix tmp_suffix
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST -a1 tmp_suffix tmp_prefix
    rm tmp_prefix tmp_suffix; echo -e "\n\e[32mPrefix suffix processing done\e[0m\n"; main
}

function substring_processing () {
    $HASHCAT -O -m$HASHTYPE $HASHLIST --show > tmp_substring
    cat tmp_substring | cut -d ':' -f2 | sort | tee tmp_passwords &>/dev/null && ./common-substr -n -f tmp_passwords > tmp_allsubstrings && rm tmp_passwords tmp_substring
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST -a1 tmp_allsubstrings tmp_allsubstrings
    rm tmp_allsubstrings; echo -e "\n\e[32mSubstring processing done\e[0m\n"; main
}

function show_info () {
    echo -e "\nInformation about the modules"
    echo "1. Default light rules: A wordlist + a set of non-heavy rules is ran agains the hashlist"
    echo "2. Default heavy rules: A wordlist + a set of heavy rules is ran agains the hashlist (take a cup or 10 of coffee)"
    echo "3. Brute force: A commonly known set of brute force tasks"
    echo "4. Iterate results: Iterate gathered results from a previous performed job, advise to run this multiple times after completing other tasks"
    echo "5. Enter your own word, for example a company name to change around with rules"
    echo "6. Enter your own word, for example a company name to brute force before and after"
    echo "7. Hybrid: Wordlist + bruteforce random combined"
    echo "8. Toggle case: Will toggle chars randomly based on toggle rules and add couple simple rules to create variations"
    echo "9. Combinator: Will combine two input wordlists to create new passwords"
    echo "10. Prefix suffix: Will take the already cracked hashes, take the prefix and suffix and put them together in variations"
    echo "11. Common substring: Will take the common substrings out of the already cracked hashes and create new variations"
    main
}

function results_processing () {
    echo "Total uniq hashes cracked:" $($HASHCAT -O -m$HASHTYPE $HASHLIST --show | tee results_cracked.txt | wc -l)
    echo "Total uniq hashes that are left:" $($HASHCAT -O -m$HASHTYPE $HASHLIST --left | tee results_lefts.txt | wc -l)
    cat results_cracked.txt | cut -d ':' -f2 | sort | tee results_clears.txt &>/dev/null
    echo -e "\nResult processing done, results can be found in \e[32mresults_cracked.txt, results_lefts.txt and results_clears.txt\e[0m\n"; main
}

function main () {
    echo -e "Hash-cracker v1.5 by crypt0rr (https://github.com/crypt0rr)\n"
    echo -e "Checking if requirements are met:"
    requirement_checker
    
    echo -e "\n0. Exit"
    echo "1. Default light rules"
    echo "2. Default heavy rules"
    echo "3. Brute force"
    echo "4. Iterate results"
    echo "5. Enter specific word/name"
    echo "6. Enter specific word/name (bruteforce)"
    echo "7. Hybrid"
    echo "8. Toggle-case"
    echo "9. Combinator"
    echo "10. Prefix suffix (advise: first run steps above)"
    echo "11. Common substring (advise: first run steps above)"
    echo "99. Show info about modules"
    echo -e "100. Show results in usable format\n"

    read -p "Please enter number OR type 'search' to find hashtypes: " START
    if [[ $START = '0' ]]; then
        echo "Bye..."; exit 1
    elif [[ $START = '1' ]]; then
        selector_hashtype; selector_hashlist; selector_wordlist; default_processing_light
    elif [[ $START = '2' ]]; then
        selector_hashtype; selector_hashlist; selector_wordlist; default_processing_heavy
    elif [[ $START = '3' ]]; then
        selector_hashtype; selector_hashlist; bruteforce_processing
    elif [[ $START = '4' ]]; then
        selector_hashtype; selector_hashlist; iterate_processing
    elif [[ $START = '5' ]]; then
        selector_hashtype; selector_hashlist; word_processing
    elif [[ $START = '6' ]]; then
        selector_hashtype; selector_hashlist; word_bruteforce
    elif [[ $START = '7' ]]; then
        selector_hashtype; selector_hashlist; selector_wordlist; hybrid_processing
    elif [[ $START = '8' ]]; then
        selector_hashtype; selector_hashlist; selector_wordlist; toggle_processing
    elif [[ $START = '9' ]]; then
        selector_hashtype; selector_hashlist; selector_wordlist; combinator_processing
    elif [[ $START = '10' ]]; then
        selector_hashtype; selector_hashlist; prefixsuffix_processing
    elif [[ $START = '11' ]]; then
        selector_hashtype; selector_hashlist; substring_processing
    elif [[ $START = '99' ]]; then
        show_info    
    elif [[ $START = '100' ]]; then
        selector_hashtype; selector_hashlist; results_processing
    elif [[ $START = 'search' ]]; then
        search_hashtype
    else
        echo -e "\e[31mNot valid, try again\n\e[0m"; main
    fi
}

main