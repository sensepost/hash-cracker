#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# Requirements
processor_bootstrap

# Rules
source scripts/rules/rules.config
RULELIST=("$big" "$fbfull" "$d3ad0ne" "$d3adhob0" "$digits1" "$digits2" "$digits3" "$dive" "$fordyv1" "$generated2" "$generated3" "$hob064" "$huge" "$leetspeak" "$NSAKEYv2" "$ORTRTS" "$OUTD" "$pantag" "$passwordpro" "$rockyou30000" "$techtrip2" "$tenKrules" "$toggles1" "$toggles2" "$toprules2020" "$TOXIC10k" "$TOXICSP" "$williamsuper")

# Temporary Files
tmp=$(dryrun_tempfile usernames)
trap 'processor_interrupt "$tmp"' INT TERM
trap 'processor_cleanup "$tmp"' EXIT

# Logic
if dry_run_enabled; then
    dryrun_note "would extract usernames from $HASHLIST into $tmp"
else
    cat $HASHLIST | cut -d '\' -f2 | awk -F: '{print $1}' >$tmp
fi
hashcat_base $tmp
for RULE in "${RULELIST[@]}"; do
    hashcat_base $tmp -r $RULE $LOOPBACK
done
if ! dry_run_enabled; then
    rm $tmp
fi
echo -e "\nUsername as Password processing with rules done\n"
