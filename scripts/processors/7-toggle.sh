#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# Interrupt handling
trap 'processor_interrupt' INT TERM

# Requirements
processor_bootstrap

# Single or multiple wordlist
read -p "Single or Multiple wordlist mode? S/M: " MODE

if [[ $MODE = [Ss] ]]; then
    source scripts/selectors/wordlist.sh
elif [[ $MODE = [Mm] ]]; then
    source scripts/selectors/multiple-wordlist.sh
fi

# Rules
source scripts/rules/rules.config
RULELIST=("$rockyou30000" "$ORTRTS" "$OUTD" "$passwordpro" "$d3ad0ne" "$d3adhob0" "$generated2" "$toprules2020" "$digits1" "$digits2" "$hob064" "$leetspeak" "$toggles1" "$toggles2")

# Logic
for RULE in "${RULELIST[@]}"; do
    hashcat_base $WORDLIST -r $toggles1 -r $RULE $LOOPBACK
    hashcat_base $WORDLIST -r $toggles2 -r $RULE $LOOPBACK
done
echo -e "\nToggle processing done\n"
