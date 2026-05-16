#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# Requirements
if [[ "$STATICCONFIG" = true ]]; then
    source hash-cracker.conf
    source scripts/runtime-overrides.sh
else
    source scripts/selectors/hashtype.sh
    source scripts/selectors/hashlist.sh
fi

# Temporary Files
tmp=$(dryrun_tempfile packrule)
trap 'processor_interrupt "$tmp" analysis.rule' INT TERM
trap 'processor_cleanup "$tmp" analysis.rule' EXIT

# Logic
if [ "$MACHINE" == "Mac" ]; then
    echo "This option is currently unavailable on Mac."
    exit 0
elif dry_run_enabled; then
    dryrun_note "would extract plaintexts from $POTFILE to $tmp"
    dryrun_note "would run python2 scripts/extensions/pack-linux/rulegen.py $tmp"
else
    cat "$POTFILE" | awk -F: '{print $NF}' | tee "$tmp" &>/dev/null
    python2 scripts/extensions/pack-linux/rulegen.py "$tmp"
    rm -f -- analysis-sorted.word analysis.word analysis-sorted.rule
fi

source scripts/selectors/wordlist.sh

$HASHCAT $KERNEL --bitmap-max=24 -d $DEVICE $HWMON $SHOWCRACKED --potfile-path="$POTFILE" -m"$HASHTYPE" "$HASHLIST" "$WORDLIST" -r analysis.rule $LOOPBACK
if ! dry_run_enabled; then
    rm -f -- analysis.rule "$tmp"
fi
echo -e "\nPACK rule processing done\n"
