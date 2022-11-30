#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh

# Rules
source scripts/rules/rules.config
RULELIST=($rule3 $rockyou30000 $ORTRTA $fbfull $pantag $OUTD $techtrip2 $TOXICSP $passwordpro $d3ad0ne $d3adhob0 $generated2 $toprules2020 $hob064 $leetspeak)

# Logic
read -p "Use potfile (p) or wordlist (w): " LIST

if [ "$LIST" == 'p' ]; then
    LIST=$POTFILE
elif [ "$LIST" == 'w' ]; then
    source scripts/selectors/wordlist.sh
    LIST=$WORDLIST
else
    echo -e "Try again...\n"; hash-cracker
fi

read -p "Minimum password (length) character limit: " NGRAM
read -p "Amount of passwords to create: " AMOUNT

cat $LIST | awk -F: '{print $NF}' | sort -u | tee tmp_pwonly &>/dev/null
./scripts/extensions/mkpass -infile tmp_pwonly -ngram $NGRAM -m $AMOUNT | tee tmp_pwcreated &>/dev/null && rm tmp_pwonly

read -p "Use rules? (y/n): " USERULES

if [[ $USERULES =~ ^[Yy]$ ]]; then
    for RULE in ${RULELIST[*]}; do
    $HASHCAT $KERNEL --bitmap-max=24 --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST tmp_pwcreated -r $RULE --loopback
    done
    rm tmp_pwcreated
elif [[ $USERULES =~ ^[Nn]$ ]]; then
    $HASHCAT $KERNEL --bitmap-max=24 --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST tmp_pwcreated
    rm tmp_pwcreated
else
    echo -e "Try again...\n"
fi

echo -e "\nMarkov-chain processing done\n"