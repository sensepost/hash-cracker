#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# Interrupt handling
trap 'processor_interrupt' INT TERM

# Requirements
processor_bootstrap

# Single or multiple wordlist
read_prompt "Single or Multiple wordlist mode? S/M: " MODE "Unable to read the wordlist mode." || exit 1

if ! processor_select_wordlist_mode "$MODE"; then
    exit 1
fi

# Rules
source scripts/rules/rules.config
RULELIST=("$rule3" "$fbtop" "$toprules2020" "$digits1" "$digits2" "$hob064" "$leetspeak" "$toggles1" "$toggles2" "$OUTD")

# Logic
hashcat_base "$WORDLIST" -r "$stacking58" -r "$stacking58" "$LOOPBACK"
for RULE in "${RULELIST[@]}"; do
    hashcat_base "$WORDLIST" -r "$stacking58" -r "$RULE" "$LOOPBACK"
done
echo -e "\nStacking with light rules done\n"
