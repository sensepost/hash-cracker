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
RULELIST=("$tenKrules" "$fbfull" "$NSAKEYv2" "$fordyv1" "$pantag" "$OUTD" "$techtrip2" "$williamsuper" "$digits3" "$dive" "$robotmyfavorite")

# Logic
hashcat_base "$WORDLIST"
for RULE in "${RULELIST[@]}"; do
    hashcat_base "$WORDLIST" -r "$RULE" "$LOOPBACK"
done
echo -e "\nDefault processing with heavy rules done\n"
