#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh
source scripts/selectors/wordlist.sh

# Logic
$HASHCAT -O --bitmap-max=24 --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a1 $WORDLIST $WORDLIST2
echo -e "\n\e[32mCombinator processing done\e[0m\n"