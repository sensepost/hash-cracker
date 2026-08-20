#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# Requirements
processor_bootstrap

# Temporary Files
tmp=$(dryrun_tempfile word)
trap 'processor_interrupt "$tmp"' INT TERM
trap 'processor_cleanup "$tmp"' EXIT

# Logic
read_prompt "Enter a word (e.g. company name): " WORD "Unable to read the custom word." || exit 1
if dry_run_enabled; then
    dryrun_note "would write custom word input to $tmp"
else
    if ! printf '%s\n' "$WORD" >"$tmp"; then
        status_error "Unable to write the custom word input."
        exit 1
    fi
    processor_require_file "$tmp" "Custom word input" || exit 1
fi
hashcat_base -a6 "$tmp" '?d?d?d?d?d?d?d?d' -i
hashcat_base -a6 "$tmp" '?l?l?l?l?l?l' -i
hashcat_base -a7 '?d?d?d?d?d?d?d?d' "$tmp" -i
hashcat_base -a7 '?l?l?l?l?l?l' "$tmp" -i
hashcat_base -a6 "$tmp" '?a?a?a?a?a' -i
hashcat_base -a7 '?a?a?a?a?a' "$tmp" -i
if ! dry_run_enabled; then
    rm -f -- "$tmp"
fi
echo -e "\nWord processing done\n"
