#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# CTRL-C catch + cleanup of temp files
function clean_up {
    rm $tmp $tmp2 $tmp3 2>/dev/null
    source hash-cracker.sh
}

trap clean_up SIGINT SIGTERM

# Requirements
if [[ "$STATICCONFIG" = true ]]; then
    source hash-cracker.conf
else
    source scripts/selectors/hashtype.sh
    source scripts/selectors/hashlist.sh
fi

# Temporary Files
tmp=$(mktemp /tmp/hash-cracker-tmp.XXXX)
tmp2=$(mktemp /tmp/hash-cracker-tmp.XXXX)
tmp3=$(mktemp /tmp/hash-cracker-tmp.XXXX)
cat $POTFILE | awk -F: '{print $NF}' | sort -u | tee $tmp &>/dev/null

# Logic
if [ "$MACHINE" == "Mac" ]; then
    python3 scripts/extensions/pack-mac/statsgen.py $tmp -o $tmp2
    python3 scripts/extensions/pack-mac/maskgen.py $tmp2 --targettime 1000 --optindex -q --pps 14000000000 --minlength=2 -o $tmp3
else
    python2 scripts/extensions/pack-linux/statsgen.py $tmp -o $tmp2
    python2 scripts/extensions/pack-linux/maskgen.py $tmp2 --targettime 1000 --optindex -q --pps 14000000000 --minlength=2 -o $tmp3
fi

$HASHCAT $KERNEL --bitmap-max=24 $HWMON $SHOWCRACKED --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a 3 $tmp3
rm $tmp $tmp2 $tmp3
echo -e "\nPACK mask processing done\n"