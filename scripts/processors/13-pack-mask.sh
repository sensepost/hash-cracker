#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# Requirements
processor_bootstrap

# Temporary Files
tmp=$(dryrun_tempfile packmask)
tmp2=$(dryrun_tempfile packmask)
tmp3=$(dryrun_tempfile packmask)
trap 'processor_interrupt "$tmp" "$tmp2" "$tmp3"' INT TERM
trap 'processor_cleanup "$tmp" "$tmp2" "$tmp3"' EXIT

# Logic
if dry_run_enabled; then
    dryrun_note "would extract unique plaintexts from $POTFILE to $tmp"
    if [ "$MACHINE" == "Mac" ]; then
        dryrun_note "would run python3 statsgen/maskgen to produce $tmp3"
    else
        dryrun_note "would run python3 statsgen/maskgen to produce $tmp3"
    fi
else
    cat "$POTFILE" | awk -F: '{print $NF}' | sort -u | tee "$tmp" &>/dev/null
    if [ "$MACHINE" == "Mac" ]; then
        python3 scripts/extensions/pack-mac/statsgen.py "$tmp" -o "$tmp2"
        python3 scripts/extensions/pack-mac/maskgen.py "$tmp2" --targettime 1000 --optindex -q --pps 14000000000 --minlength=2 -o "$tmp3"
    else
        python3 scripts/extensions/pack-linux/statsgen.py "$tmp" -o "$tmp2"
        python3 scripts/extensions/pack-linux/maskgen.py "$tmp2" --targettime 1000 --optindex -q --pps 14000000000 --minlength=2 -o "$tmp3"
    fi
fi

hashcat_base -a 3 "$tmp3"
if ! dry_run_enabled; then
    rm -f -- "$tmp" "$tmp2" "$tmp3"
fi
echo -e "\nPACK mask processing done\n"
