#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# CTRL-C catch + cleanup of temp files
function clean_up {
    rm -f -- "$tmp" "$tmp2" "$tmp3" 2>/dev/null
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

# Temporary Files
tmp=$(dryrun_tempfile packmask)
tmp2=$(dryrun_tempfile packmask)
tmp3=$(dryrun_tempfile packmask)

# Logic
if dry_run_enabled; then
    dryrun_note "would extract unique plaintexts from $POTFILE to $tmp"
    if [ "$MACHINE" == "Mac" ]; then
        dryrun_note "would run python3 statsgen/maskgen to produce $tmp3"
    else
        dryrun_note "would run python2 statsgen/maskgen to produce $tmp3"
    fi
else
    cat "$POTFILE" | awk -F: '{print $NF}' | sort -u | tee "$tmp" &>/dev/null
    if [ "$MACHINE" == "Mac" ]; then
        python3 scripts/extensions/pack-mac/statsgen.py "$tmp" -o "$tmp2"
        python3 scripts/extensions/pack-mac/maskgen.py "$tmp2" --targettime 1000 --optindex -q --pps 14000000000 --minlength=2 -o "$tmp3"
    else
        python2 scripts/extensions/pack-linux/statsgen.py "$tmp" -o "$tmp2"
        python2 scripts/extensions/pack-linux/maskgen.py "$tmp2" --targettime 1000 --optindex -q --pps 14000000000 --minlength=2 -o "$tmp3"
    fi
fi

$HASHCAT $KERNEL --bitmap-max=24 -d $DEVICE $HWMON $SHOWCRACKED --potfile-path="$POTFILE" -m"$HASHTYPE" "$HASHLIST" -a 3 "$tmp3"
if ! dry_run_enabled; then
    rm -f -- "$tmp" "$tmp2" "$tmp3"
fi
echo -e "\nPACK mask processing done\n"
