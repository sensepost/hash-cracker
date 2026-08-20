#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# Requirements
processor_bootstrap

# Temporary Files
tmp=$(dryrun_tempfile packmask-1)
tmp2=$(dryrun_tempfile packmask-2)
tmp3=$(dryrun_tempfile packmask-3)
trap 'processor_interrupt "$tmp" "$tmp2" "$tmp3"' INT TERM
trap 'processor_cleanup "$tmp" "$tmp2" "$tmp3"' EXIT

# Logic
if dry_run_enabled; then
    dryrun_note "would extract unique plaintexts from $POTFILE to $tmp"
    dryrun_note "would run python3 statsgen/maskgen to produce $tmp3"
else
    if ! cat "$POTFILE" | awk -F: '{print $NF}' | LC_ALL=C sort -u | tee "$tmp" &>/dev/null; then
        status_error "PACK mask plaintext extraction failed."
        exit 1
    fi
    if [ "$MACHINE" == "Mac" ]; then
        if ! processor_run python3 scripts/extensions/pack-mac/statsgen.py "$tmp" -o "$tmp2"; then
            status_error "PACK statistics generation failed."
            exit 1
        fi
        if ! processor_run python3 scripts/extensions/pack-mac/maskgen.py "$tmp2" --targettime 1000 --optindex -q --pps 14000000000 --minlength=2 -o "$tmp3"; then
            status_error "PACK mask generation failed."
            exit 1
        fi
    else
        if ! processor_run python3 scripts/extensions/pack-linux/statsgen.py "$tmp" -o "$tmp2"; then
            status_error "PACK statistics generation failed."
            exit 1
        fi
        if ! processor_run python3 scripts/extensions/pack-linux/maskgen.py "$tmp2" --targettime 1000 --optindex -q --pps 14000000000 --minlength=2 -o "$tmp3"; then
            status_error "PACK mask generation failed."
            exit 1
        fi
    fi
    processor_require_file "$tmp3" "PACK mask output" || exit 1
fi

hashcat_base -a 3 "$tmp3"
if ! dry_run_enabled; then
    rm -f -- "$tmp" "$tmp2" "$tmp3"
fi
echo -e "\nPACK mask processing done\n"
