#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# Requirements
processor_bootstrap

fingerprint_segment_max="${FINGERPRINT_SEGMENT_MAX:-8}"
case "$fingerprint_segment_max" in
    '' | *[!0-9]* | 0)
        echo "Invalid FINGERPRINT_SEGMENT_MAX: $fingerprint_segment_max"
        exit 1
        ;;
esac
fingerprint_candidate_max=$((fingerprint_segment_max * 2))

# Temporary Files
tmp=$(dryrun_tempfile fingerprint)
tmp2=$(dryrun_tempfile fingerprint)
trap 'processor_interrupt "$tmp" "$tmp2"' INT TERM
trap 'processor_cleanup "$tmp" "$tmp2"' EXIT

# Logic
if dry_run_enabled; then
    dryrun_note "would extract unique plaintexts from $POTFILE to $tmp"
    dryrun_note "would generate fingerprint fragments up to $fingerprint_segment_max chars, producing combinator candidates up to $fingerprint_candidate_max chars"
else
    awk -F: '{print $NF}' "$POTFILE" | sort -u >"$tmp"
    LC_ALL=C awk -v max_len="$fingerprint_segment_max" '
        function rotl(s) { return substr(s, 2) substr(s, 1, 1) }
        function rotr(s) { return substr(s, length(s), 1) substr(s, 1, length(s) - 1) }
        function emit_chunks(s, n,    j) {
            for (j = 1; j + n - 1 <= length(s); j += n) {
                print substr(s, j, n)
            }
        }
        length($0) {
            line = $0
            line_len = length(line)
            for (n = 1; n <= max_len && n <= line_len; n++) {
                rotated = line
                for (i = 0; i < n; i++) {
                    emit_chunks(rotated, n)
                    rotated = rotl(rotated)
                }
                for (i = 0; i < n; i++) {
                    emit_chunks(rotated, n)
                    rotated = rotr(rotated)
                }
            }
        }
    ' "$tmp" | sort -u >"$tmp2" && rm -f -- "$tmp"
fi

hashcat_base -a 1 "$tmp2" "$tmp2"
if ! dry_run_enabled; then
    rm -f -- "$tmp2"
fi
echo -e "\nFingerprint attack done\n"
