#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# CTRL-C catch + cleanup of temp files
function clean_up {
    exit 0
    rm $tmp 2>/dev/null
}

# Requirements
if [[ "$STATICCONFIG" = true ]]; then
    source hash-cracker.conf
    source scripts/runtime-overrides.sh
else
    source scripts/selectors/hashtype.sh
    source scripts/selectors/hashlist.sh
fi

# Temporary Files
tmp=$(dryrun_tempfile word)

# Logic
read -p "Enter a word (e.g. company name): " WORD
if dry_run_enabled; then
    dryrun_note "would write custom word input to $tmp"
else
    echo $WORD >$tmp
fi
hashcat_base -a6 $tmp '?d?d?d?d?d?d?d?d' -i
hashcat_base -a6 $tmp '?l?l?l?l?l?l' -i
hashcat_base -a7 '?d?d?d?d?d?d?d?d' $tmp -i
hashcat_base -a7 '?l?l?l?l?l?l' $tmp -i
hashcat_base -a6 $tmp '?a?a?a?a?a' -i
hashcat_base -a7 '?a?a?a?a?a' $tmp -i
if ! dry_run_enabled; then
    rm $tmp
fi
echo -e "\nWord processing done\n"
