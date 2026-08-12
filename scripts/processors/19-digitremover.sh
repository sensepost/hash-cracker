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
else
    if [ ! -f "$POTFILE" ]; then
        status_error "Digit-removal source potfile is missing: $POTFILE"
        exit 1
    fi
    if ! cut -d: -f2- "$POTFILE" | awk '!/^\$HEX\[/' | sed 's/[0-9]//g' >"$tmp"; then
        status_error "Unable to generate digit-removal candidates from the potfile."
        exit 1
    fi
    if ! cut -d: -f2- "$POTFILE" | LC_ALL=C awk '
        function hex_digit(value) {
            return index("0123456789abcdef", tolower(value)) - 1
        }
        /^\$HEX\[/ {
            encoded = $0
            sub(/^\$HEX\[/, "", encoded)
            sub(/\]$/, "", encoded)
            if (length(encoded) % 2 != 0 || encoded !~ /^[[:xdigit:]]*$/) {
                exit 1
            }
            decoded = ""
            for (position = 1; position <= length(encoded); position += 2) {
                high = hex_digit(substr(encoded, position, 1))
                low = hex_digit(substr(encoded, position + 1, 1))
                if (high < 0 || low < 0) {
                    exit 1
                }
                decoded = decoded sprintf("%c", high * 16 + low)
            }
            print decoded
        }
    ' | LC_ALL=C sed 's/[0-9]//g' >>"$tmp"; then
        status_error "Unable to decode hexadecimal potfile candidates."
        exit 1
    fi
    processor_require_file "$tmp" "Digit-removal output" || exit 1
fi

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
if ! dry_run_enabled; then
    rm -f -- "$tmp"
fi
echo -e "\nDigit removal / Hybrid processing done\n"
