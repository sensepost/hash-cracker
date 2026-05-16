#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# Interrupt handling
trap 'processor_interrupt' INT TERM

# Requirements
if [[ "$STATICCONFIG" = true ]]; then
    source hash-cracker.conf
    source scripts/runtime-overrides.sh
else
    source scripts/selectors/hashtype.sh
    source scripts/selectors/hashlist.sh
fi
source scripts/selectors/multiple-wordlist.sh

# Logic
hashcat_base -a1 $WORDLIST $WORDLIST2
echo -e "\nCombinator processing done\n"
