#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# Requirements
processor_bootstrap

# Rules
source scripts/rules/rules.config
RULELIST=("$tenKrules" "$NSAKEYv2" "$fordyv1" "$pantag" "$OUTD" "$techtrip2" "$williamsuper" "$digits3" "$dive")

# Temporary Files
tmp=$(dryrun_tempfile word)
trap 'processor_interrupt "$tmp"' INT TERM
trap 'processor_cleanup "$tmp"' EXIT

# Logic
read -p "Enter a word (e.g. company name): " WORD
if dry_run_enabled; then
    dryrun_note "would write custom word input to $tmp"
else
    echo $WORD >$tmp
fi
for RULE in "${RULELIST[@]}"; do
    hashcat_base $tmp -r $RULE $LOOPBACK
done
if ! dry_run_enabled; then
    rm $tmp
fi
echo -e "\nWord processing done\n"
