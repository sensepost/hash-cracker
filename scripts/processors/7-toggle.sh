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
RULELIST=($rockyou30000 $ORTRTS $OUTD $passwordpro $d3ad0ne $d3adhob0 $generated2 $toprules2020 $digits1 $digits2 $hob064 $leetspeak $toggles1 $toggles2)

# Logic
for RULE in ${RULELIST[*]}; do
    $HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST $WORDLIST -r $toggles1 -r $RULE $LOOPBACK
    $HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST $WORDLIST -r $toggles2 -r $RULE $LOOPBACK
done
echo -e "\nToggle processing done\n"