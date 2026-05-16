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
RULELIST=("$rule3" "$robotmyfavorite" "$fbfull" "$tenKrules" "$NSAKEYv2" "$fordyv1" "$pantag" "$OUTD" "$TOXICSP" "$techtrip2" "$williamsuper" "$digits3" "$dive" "$TOXIC10k" "$big" "$generated3" "$huge")

# Temporary Files
tmp=$(dryrun_tempfile iterate)

# Logic
for RULE in "${RULELIST[@]}"; do
    if dry_run_enabled; then
        dryrun_note "would extract unique plaintexts from $POTFILE to $tmp"
    else
        cat $POTFILE | awk -F: '{print $NF}' | sort -u | tee $tmp &>/dev/null
    fi
    hashcat_base $tmp -r $RULE $LOOPBACK
done
if ! dry_run_enabled; then
    rm $tmp
fi
echo -e "\nIteration processing done\n"
