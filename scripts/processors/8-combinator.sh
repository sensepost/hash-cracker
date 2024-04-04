#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# CTRL-C catch
function clean_up {
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
source scripts/selectors/multiple-wordlist.sh

# Logic
$HASHCAT $KERNEL --bitmap-max=24 $HWMON $SHOWCRACKED --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a1 $WORDLIST $WORDLIST2 
echo -e "\nCombinator processing done\n"