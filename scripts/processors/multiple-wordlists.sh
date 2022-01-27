#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh
source scripts/selectors/wordlist.sh

# Rules
source scripts/rules/rules.config
RULELIST=($ORTRTA)

# Logic
$HASHCAT -O --bitmap-max=24 --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST $WORDLIST
for RULE in ${RULELIST[*]}; do
    $HASHCAT -O --bitmap-max=24 --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST $WORDLIST -r $RULE --loopback
done
echo -e "\n\e[32mMultiple wordlists done\e[0m\n"