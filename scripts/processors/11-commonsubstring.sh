#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# CTRL-C catch + cleanup of temp files
function clean_up {
    rm -f -- "$tmp2" "$tmp3" "$tmp4" 2>/dev/null
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
tmp2=$(mktemp /tmp/hash-cracker-tmp.XXXX)
tmp3=$(mktemp /tmp/hash-cracker-tmp.XXXX)
tmp4=$(mktemp /tmp/hash-cracker-tmp.XXXX)
awk -F: '{print $NF}' "$POTFILE" >"$tmp2"

# Logic
if [ "$MACHINE" == "Mac" ]; then
    sort "$tmp2" | tee "$tmp3" &>/dev/null && ./scripts/extensions/common-substr-mac -n -f "$tmp3" >"$tmp4" && rm -f -- "$tmp3" "$tmp2"
else
    sort "$tmp2" | tee "$tmp3" &>/dev/null && ./scripts/extensions/common-substr-linux -n -f "$tmp3" >"$tmp4" && rm -f -- "$tmp3" "$tmp2"
fi

$HASHCAT $KERNEL --bitmap-max=24 -d $DEVICE $HWMON $SHOWCRACKED --potfile-path="$POTFILE" -m"$HASHTYPE" "$HASHLIST" -a1 "$tmp4" "$tmp4"
rm -f -- "$tmp4"
echo -e "\nSubstring processing done\n"
