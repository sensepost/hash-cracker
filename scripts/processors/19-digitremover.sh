#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# Requirements
processor_bootstrap

# Rules
source scripts/rules/rules.config
RULELIST=("$fbfull" "$ORTRTS" "$NSAKEYv2" "$techtrip2")

# Temporary Files
tmp=$(dryrun_tempfile digitremover)
trap 'processor_interrupt "$tmp"' INT TERM
trap 'processor_cleanup "$tmp"' EXIT

# Digitfilter
if dry_run_enabled; then
    dryrun_note "would generate digit-stripped candidate list from $POTFILE into $tmp"
elif campaign_reuse_preserved_inputs "$tmp"; then
    :
elif [ "${CAMPAIGN_INPUT_REUSE_ERROR:-0}" -ne 0 ]; then
    exit 1
else
    if [ ! -f "$POTFILE" ]; then
        status_error "Digit-removal source potfile is missing: $POTFILE"
        exit 1
    fi
    if ! processor_extract_plaintexts "$POTFILE" | LC_ALL=C sed 's/[0-9]//g' >"$tmp"; then
        status_error "Unable to decode potfile candidates for digit removal."
        exit 1
    fi
    processor_require_file "$tmp" "Digit-removal output" || exit 1
fi

campaign_register_generated_inputs "$tmp" || exit 1

# Logic
hashcat_base -a6 "$tmp" -j c '?s?d?d?d?d' --increment
hashcat_base -a6 "$tmp" -j c '?d?d?d?d?s' --increment
hashcat_base -a6 "$tmp" -j c '?a?a' --increment
hashcat_base -a6 "$tmp" '?s?d?d?d?d' --increment
hashcat_base -a6 "$tmp" '?d?d?d?d?s' --increment
hashcat_base -a6 "$tmp" '?a?a' --increment

for RULE in "${RULELIST[@]}"; do
    hashcat_base "$tmp" -r "$RULE"
done
echo -e "\nDigit removal / Hybrid processing done\n"
