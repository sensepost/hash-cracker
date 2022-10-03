#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh

# Logic
cat $POTFILE | awk -F: '{print $NF}' | tee tmp_pwonly &>/dev/null
python2 scripts/extensions/pack/rulegen.py tmp_pwonly
rm analysis-sorted.word analysis.word analysis-sorted.rule

source scripts/selectors/wordlist.sh

$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST $WORDLIST -r analysis.rule --loopback
rm analysis.rule tmp_pwonly
echo -e "\nPACK rule processing done\n"