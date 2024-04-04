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
cat $POTFILE | awk -F: '{print $NF}' | tee $tmp &>/dev/null

# Logic
if [ "$MACHINE" == "Mac" ]; then
    cat $tmp | awk -F: '{print $NF}' | sort | tee $tmp2 &>/dev/null && ./scripts/extensions/common-substr-mac -n -p -f $tmp2 > $tmp3 && ./scripts/extensions/common-substr-mac -n -s -f $tmp2 > $tmp4 && rm $tmp2 $tmp
else
    cat $tmp | awk -F: '{print $NF}' | sort | tee $tmp2 &>/dev/null && ./scripts/extensions/common-substr-linux -n -p -f $tmp2 > $tmp3 && ./scripts/extensions/common-substr-linux -n -s -f $tmp2 > $tmp4 && rm $tmp2 $tmp
fi

$HASHCAT $KERNEL --bitmap-max=24 $HWMON $SHOWCRACKED --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a1 $tmp3 $tmp4
$HASHCAT $KERNEL --bitmap-max=24 $HWMON $SHOWCRACKED --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a1 $tmp4 $tmp3
rm $tmp3 $tmp4
echo -e "\nPrefix suffix processing done\n"