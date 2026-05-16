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
RULELIST=("$fbfull" "$ORTRTS" "$NSAKEYv2" "$techtrip2")

# Temporary Files
tmp=$(dryrun_tempfile digitremover)

# Digitfilter
if dry_run_enabled; then
    dryrun_note "would generate digit-stripped candidate list from $POTFILE into $tmp"
else
    cat $POTFILE | cut -d: -f2- | grep -v '^\$HEX\[' | sed 's/[0-9]//g' | tee $tmp &>/dev/null
    cat $POTFILE | cut -d: -f2- | grep '^\$HEX\[' | sed "s/\$HEX\[\(.*\)\]/\10a/" | xxd -r -ps | LC_ALL=C sed 's/[0-9]//g' | LC_ALL=C tee -a $tmp &>/dev/null
fi

# Logic
hashcat_base -a6 $tmp -j c '?s?d?d?d?d' --increment
hashcat_base -a6 $tmp -j c '?d?d?d?d?s' --increment
hashcat_base -a6 $tmp -j c '?a?a' --increment
hashcat_base -a6 $tmp '?s?d?d?d?d' --increment
hashcat_base -a6 $tmp '?d?d?d?d?s' --increment
hashcat_base -a6 $tmp '?a?a' --increment

for RULE in "${RULELIST[@]}"; do
    hashcat_base $tmp -r $RULE
done
if ! dry_run_enabled; then
    rm $tmp
fi
echo -e "\nDigit removal / Hybrid processing done\n"
