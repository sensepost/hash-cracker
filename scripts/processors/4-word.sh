#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# CTRL-C catch + cleanup of temp files
function clean_up {
    rm $tmp 2>/dev/null
    exit 0
}

trap clean_up SIGINT SIGTERM

# Requirements
if [[ "$STATICCONFIG" = true ]]; then
    source hash-cracker.conf
    source scripts/runtime-overrides.sh
else
    source scripts/selectors/hashtype.sh
    source scripts/selectors/hashlist.sh
fi

# Rules
source scripts/rules/rules.config
RULELIST=("$tenKrules" "$NSAKEYv2" "$fordyv1" "$pantag" "$OUTD" "$techtrip2" "$williamsuper" "$digits3" "$dive")

# Temporary Files
tmp=$(dryrun_tempfile word)

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
