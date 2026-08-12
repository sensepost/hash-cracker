#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# Interrupt handling
trap 'processor_interrupt' INT TERM

# Requirements
processor_bootstrap
source scripts/selectors/multiple-wordlist.sh

# Logic
hashcat_base -a1 "$WORDLIST" "$WORDLIST2"
echo -e "\nCombinator processing done\n"
