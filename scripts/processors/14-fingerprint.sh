#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# CTRL-C catch + cleanup of temp files
function clean_up {
    rm $tmp $tmp2 2>/dev/null
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
cat $POTFILE | awk -F: '{print $NF}' | sort -u | tee $tmp &>/dev/null

# Logic
if [ "$MACHINE" == "Mac" ]; then
    ./scripts/extensions/hashcat-utils-mac/bin/expander.bin < $tmp | iconv -f ISO-8859-1 -t UTF-8//TRANSLIT | sort -u > $tmp2 && rm $tmp
else
    ./scripts/extensions/hashcat-utils-linux/bin/expander.bin < $tmp | sort -u > $tmp2 && rm $tmp
fi

$HASHCAT $KERNEL --bitmap-max=24 $HWMON $SHOWCRACKED --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a 1 $tmp2 $tmp2
rm $tmp2
echo -e "\nFingerprint attack done\n"