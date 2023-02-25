#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh

# Cleanup
function clean_up {
    rm $tmp $tmp2 2>/dev/null
    exit
}

trap clean_up SIGINT SIGTERM

# Temporary Files
tmp=$(mktemp /tmp/hash-cracker-tmp.XXXX)
tmp2=$(mktemp /tmp/hash-cracker-tmp.XXXX)

# Logic
cat $POTFILE | awk -F: '{print $NF}' | sort -u | tee $tmp &>/dev/null
./scripts/extensions/hashcat-utils/bin/expander.bin < $tmp | sort -u > $tmp2 && rm $tmp
$HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a 1 $tmp2 $tmp2
rm $tmp2
echo -e "\nFingerprint attack done\n"