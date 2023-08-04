#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh
source scripts/selectors/multiple-wordlist.sh

# Rules
source scripts/rules/rules.config
RULELIST=($ORTRTS)

# Logic
$HASHCAT $KERNEL --bitmap-max=24 $HWMON --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST $WORDLIST
for RULE in ${RULELIST[*]}; do
    $HASHCAT $KERNEL --bitmap-max=24 $HWMON --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST $WORDLIST -r $RULE $LOOPBACK
done
echo -e "\nMultiple wordlists done\n"