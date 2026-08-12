#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# Requirements
processor_bootstrap
common_substr_bin="${COMMON_SUBSTR_BIN:-scripts/extensions/common-substr-linux}"

# Temporary Files
tmp2=$(dryrun_tempfile commonsubstr-2)
tmp3=$(dryrun_tempfile commonsubstr-3)
tmp4=$(dryrun_tempfile commonsubstr-4)
trap 'processor_interrupt "$tmp2" "$tmp3" "$tmp4"' INT TERM
trap 'processor_cleanup "$tmp2" "$tmp3" "$tmp4"' EXIT

# Logic
if dry_run_enabled; then
    dryrun_note "would extract plaintexts from $POTFILE to $tmp2"
    if [ "$MACHINE" == "Mac" ]; then
        dryrun_note "would run common-substr-mac generation into $tmp4"
    else
        dryrun_note "would run common-substr-linux generation into $tmp4"
    fi
else
    if ! awk -F: '{print $NF}' "$POTFILE" >"$tmp2"; then
        status_error "Common-substring plaintext extraction failed."
        exit 1
    fi
    if ! {
        sort "$tmp2" | tee "$tmp3" &>/dev/null \
            && "$common_substr_bin" -n -f "$tmp3" >"$tmp4" \
            && rm -f -- "$tmp3" "$tmp2"
    }; then
        status_error "Common-substring helper preprocessing failed."
        exit 1
    fi
    processor_require_file "$tmp4" "Common-substring output" || exit 1
fi

hashcat_base -a1 "$tmp4" "$tmp4"
if ! dry_run_enabled; then
    rm -f -- "$tmp4"
fi
echo -e "\nSubstring processing done\n"
