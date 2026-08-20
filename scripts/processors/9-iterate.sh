#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# Requirements
processor_bootstrap

# Rules
source scripts/rules/rules.config
RULELIST=("$rule3" "$robotmyfavorite" "$fbfull" "$tenKrules" "$NSAKEYv2" "$fordyv1" "$pantag" "$OUTD" "$TOXICSP" "$techtrip2" "$williamsuper" "$digits3" "$dive" "$TOXIC10k" "$big" "$generated3" "$huge")

# Temporary Files
tmp=$(dryrun_tempfile iterate)
trap 'processor_interrupt "$tmp"' INT TERM
trap 'processor_cleanup "$tmp"' EXIT

# Logic
if dry_run_enabled; then
    dryrun_note "would extract unique plaintexts from $POTFILE to $tmp"
else
    if ! awk -F: '{print $NF}' "$POTFILE" | LC_ALL=C sort -u >"$tmp"; then
        status_error "Iteration plaintext extraction failed."
        exit 1
    fi
    processor_require_file "$tmp" "Iteration output" || exit 1
fi

for RULE in "${RULELIST[@]}"; do
    hashcat_base "$tmp" -r "$RULE" "$LOOPBACK"
done
if ! dry_run_enabled; then
    rm -f -- "$tmp"
fi
echo -e "\nIteration processing done\n"
