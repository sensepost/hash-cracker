#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# CTRL-C catch + cleanup of temp files
function clean_up {
    rm $tmp $tmp2 $tmp3 $tmp4 2>/dev/null
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
tmp4=$(mktemp /tmp/hash-cracker-tmp.XXXX)
cat $POTFILE | awk -F: '{print $NF}' | tee $tmp &>/dev/null > $tmp2; rm $tmp

# Logic
if [ "$MACHINE" == "Mac" ]; then
    cat $tmp2 | awk -F: '{print $NF}' | sort | tee $tmp3 &>/dev/null && ./scripts/extensions/common-substr-mac -n -f $tmp3 > $tmp4 && rm $tmp3 $tmp2
else
    cat $tmp2 | awk -F: '{print $NF}' | sort | tee $tmp3 &>/dev/null && ./scripts/extensions/common-substr-linux -n -f $tmp3 > $tmp4 && rm $tmp3 $tmp2
fi

$HASHCAT $KERNEL --bitmap-max=24 $HWMON $SHOWCRACKED --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a1 $tmp4 $tmp4
rm $tmp4
echo -e "\nSubstring processing done\n"