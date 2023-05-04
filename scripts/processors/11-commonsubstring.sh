#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh

# Cleanup
function clean_up {
    rm $tmp $tmp2 $tmp3 $tmp4 2>/dev/null
    exit
}

trap clean_up SIGINT SIGTERM

# Temporary Files
tmp=$(mktemp /tmp/hash-cracker-tmp.XXXX)
tmp2=$(mktemp /tmp/hash-cracker-tmp.XXXX)
tmp3=$(mktemp /tmp/hash-cracker-tmp.XXXX)
tmp4=$(mktemp /tmp/hash-cracker-tmp.XXXX)

# Logic
cat $POTFILE | awk -F: '{print $NF}' | tee $tmp &>/dev/null > $tmp2; rm $tmp
cat $tmp2 | awk -F: '{print $NF}' | sort | tee $tmp3 &>/dev/null && ./scripts/extensions/common-substr -n -f $tmp3 > $tmp4 && rm $tmp3 $tmp2
$HASHCAT $KERNEL --bitmap-max=24 $HWMON --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a1 $tmp4 $tmp4
rm $tmp4; echo -e "\nSubstring processing done\n"