#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh
source scripts/selectors/wordlist.sh

# Rules
source scripts/rules/rules.config
RULELIST=($rockyou30000 $ORTRTA $OUTD $passwordpro $d3ad0ne $d3adhob0 $generated2 $toprules2020 $digits1 $digits2 $hob064 $leetspeak $toggles1 $toggles2)

# Logic
for RULE in ${RULELIST_SMALL[*]}; do
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST $WORDLIST -r $toggles1 -r $RULE --loopback
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST $WORDLIST -r $toggles2 -r $RULE --loopback
done
echo -e "\n\e[32mToggle processing done\e[0m\n"