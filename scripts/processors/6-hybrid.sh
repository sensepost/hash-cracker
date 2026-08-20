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

# Logic
hashcat_base -a6 "$WORDLIST" -j c '?s?d?d?d?d' --increment
hashcat_base -a6 "$WORDLIST" -j c '?d?d?d?d?s' --increment
hashcat_base -a6 "$WORDLIST" -j c '?a?a' --increment
hashcat_base -a6 "$WORDLIST" '?s?d?d?d?d' --increment
hashcat_base -a6 "$WORDLIST" '?d?d?d?d?s' --increment
hashcat_base -a6 "$WORDLIST" '?a?a' --increment
echo -e "\nHybrid processing done\n"
