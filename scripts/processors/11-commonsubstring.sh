#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# Requirements
processor_bootstrap

# Temporary Files
tmp2=$(dryrun_tempfile commonsubstr)
tmp3=$(dryrun_tempfile commonsubstr)
tmp4=$(dryrun_tempfile commonsubstr)
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
    awk -F: '{print $NF}' "$POTFILE" >"$tmp2"
    if [ "$MACHINE" == "Mac" ]; then
        sort "$tmp2" | tee "$tmp3" &>/dev/null && ./scripts/extensions/common-substr-mac -n -f "$tmp3" >"$tmp4" && rm -f -- "$tmp3" "$tmp2"
    else
        sort "$tmp2" | tee "$tmp3" &>/dev/null && ./scripts/extensions/common-substr-linux -n -f "$tmp3" >"$tmp4" && rm -f -- "$tmp3" "$tmp2"
    fi
fi

hashcat_base -a1 "$tmp4" "$tmp4"
if ! dry_run_enabled; then
    rm -f -- "$tmp4"
fi
echo -e "\nSubstring processing done\n"
