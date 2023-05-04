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
cat $POTFILE | awk -F: '{print $NF}' | tee $tmp &>/dev/null
cat $tmp | awk -F: '{print $NF}' | sort | tee $tmp2 &>/dev/null && ./scripts/extensions/common-substr -n -p -f $tmp2 > $tmp3 && ./scripts/extensions/common-substr -n -s -f $tmp2 > $tmp4 && rm $tmp2 $tmp
$HASHCAT $KERNEL --bitmap-max=24 $HWMON --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a1 $tmp3 $tmp4
$HASHCAT $KERNEL --bitmap-max=24 $HWMON --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a1 $tmp4 $tmp3
rm $tmp3 $tmp4; echo -e "\nPrefix suffix processing done\n"