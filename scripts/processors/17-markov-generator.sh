#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# CTRL-C catch + cleanup of temp files
function clean_up {
    rm $tmp $tmp2 2>/dev/null
    source hash-cracker.sh
}

trap clean_up SIGINT SIGTERM

# Requirements
if [[ "$STATICCONFIG" = true ]]; then
    source hash-cracker.conf
else
    source scripts/selectors/hashtype.sh
    source scripts/selectors/hashlist.sh
fi

# Rules
source scripts/rules/rules.config
RULELIST=($rule3 $rockyou30000 $ORTRTS $fbfull $pantag $OUTD $techtrip2 $TOXICSP $passwordpro $d3ad0ne $d3adhob0 $generated2 $toprules2020 $hob064 $leetspeak)

# Temporary Files
tmp=$(mktemp /tmp/hash-cracker-tmp.XXXX)
tmp2=$(mktemp /tmp/hash-cracker-tmp.XXXX)

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

cat $LIST | awk -F: '{print $NF}' | sort -u | tee $tmp &>/dev/null

if [ "$MACHINE" == "Mac" ]; then
    ./scripts/extensions/mkpass-mac -infile $tmp -ngram $NGRAM -m $AMOUNT | tee $tmp2 &>/dev/null && rm $tmp
else
    ./scripts/extensions/mkpass-linux -infile $tmp -ngram $NGRAM -m $AMOUNT | tee $tmp2 &>/dev/null && rm $tmp
fi

read -p "Use rules? (y/n): " USERULES

if [[ $USERULES =~ ^[Yy]$ ]]; then
    for RULE in ${RULELIST[*]}; do
    $HASHCAT $KERNEL --bitmap-max=24 $HWMON $SHOWCRACKED --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST $tmp2 -r $RULE $LOOPBACK
    done
    rm $tmp2
elif [[ $USERULES =~ ^[Nn]$ ]]; then
    $HASHCAT $KERNEL --bitmap-max=24 $HWMON $SHOWCRACKED --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST $tmp2
    rm $tmp2
else
    echo -e "Try again...\n"
fi

echo -e "\nMarkov-chain processing done\n"