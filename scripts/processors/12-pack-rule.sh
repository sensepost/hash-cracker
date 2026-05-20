#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# Requirements
processor_bootstrap

# Temporary Files
tmp=$(dryrun_tempfile packrule)
trap 'processor_interrupt "$tmp" analysis.rule' INT TERM
trap 'processor_cleanup "$tmp" analysis.rule' EXIT
rulegen_path="scripts/extensions/pack-linux/rulegen.py"
if [ "$MACHINE" == "Mac" ]; then
    rulegen_path="scripts/extensions/pack-mac/rulegen.py"
fi

# Logic
if dry_run_enabled; then
    dryrun_note "would extract plaintexts from $POTFILE to $tmp"
    dryrun_note "would run python3 $rulegen_path $tmp"
else
    cat "$POTFILE" | awk -F: '{print $NF}' | tee "$tmp" &>/dev/null
    python3 "$rulegen_path" "$tmp"
    rm -f -- analysis-sorted.word analysis.word analysis-sorted.rule
fi

source scripts/selectors/wordlist.sh

hashcat_base "$WORDLIST" -r analysis.rule $LOOPBACK
if ! dry_run_enabled; then
    rm -f -- analysis.rule "$tmp"
fi
echo -e "\nPACK rule processing done\n"
