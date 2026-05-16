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

# Single or multiple wordlist
read -p "Single or Multiple wordlist mode? S/M: " MODE

if [[ $MODE = [Ss] ]]; then
    source scripts/selectors/wordlist.sh
elif [[ $MODE = [Mm] ]]; then
    source scripts/selectors/multiple-wordlist.sh
fi

# Logic
hashcat_base -a6 $WORDLIST -j c '?s?d?d?d?d' --increment
hashcat_base -a6 $WORDLIST -j c '?d?d?d?d?s' --increment
hashcat_base -a6 $WORDLIST -j c '?a?a' --increment
hashcat_base -a6 $WORDLIST '?s?d?d?d?d' --increment
hashcat_base -a6 $WORDLIST '?d?d?d?d?s' --increment
hashcat_base -a6 $WORDLIST '?a?a' --increment
echo -e "\nHybrid processing done\n"
