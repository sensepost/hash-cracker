#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh

# Single or multiple wordlist
read -p "Single or Multiple wordlist mode? S/M: " MODE

if [[ $MODE = [Ss] ]]; then
    source scripts/selectors/wordlist.sh
elif [[ $MODE = [Mm] ]]; then
    source scripts/selectors/multiple-wordlist.sh
fi

# Rules
source scripts/rules/rules.config
RULELIST=($rule3 $rockyou30000 $ORTRTA $fbtop $OUTD $TOXICSP $passwordpro $d3ad0ne $d3adhob0 $generated2 $toprules2020 $digits1 $digits2 $hob064 $leetspeak $toggles1 $toggles2)

# Logic
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST $WORDLIST
for RULE in ${RULELIST[*]}; do
    $HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST $WORDLIST -r $RULE --loopback
done
echo -e "\nDefault processing with light rules done\n"