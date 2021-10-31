#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh

# Logic
$HASHCAT -O -m$HASHTYPE $HASHLIST --show | cut -d ':' -f2 | tee tmp_pwonly &>/dev/null
python2 scripts/extensions/rulegen.py tmp_pwonly
rm analysis-sorted.word analysis.word analysis-sorted.rule

source scripts/selectors/wordlist.sh

$HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST $WORDLIST -r analysis.rule --loopback
rm analysis.rule tmp_pwonly
echo -e "\n\e[32mPACK processing done\e[0m\n"