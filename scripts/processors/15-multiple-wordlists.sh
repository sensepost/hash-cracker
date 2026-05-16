#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# Interrupt handling
trap 'processor_interrupt' INT TERM

# Requirements
processor_bootstrap
source scripts/selectors/multiple-wordlist.sh

# Rules
source scripts/rules/rules.config
RULELIST=("$ORTRTS")

# Logic
hashcat_base $WORDLIST
for RULE in "${RULELIST[@]}"; do
    hashcat_base $WORDLIST -r $RULE $LOOPBACK
done
echo -e "\nMultiple wordlists done\n"
