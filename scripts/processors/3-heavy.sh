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
RULELIST=("$tenKrules" "$fbfull" "$NSAKEYv2" "$fordyv1" "$pantag" "$OUTD" "$techtrip2" "$williamsuper" "$digits3" "$dive" "$robotmyfavorite")

# Logic
hashcat_base $WORDLIST
for RULE in "${RULELIST[@]}"; do
    hashcat_base $WORDLIST -r $RULE $LOOPBACK
done
echo -e "\nDefault processing with heavy rules done\n"
