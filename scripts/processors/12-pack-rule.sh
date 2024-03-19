#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# CTRL-C catch + cleanup of temp files
function clean_up {
    rm $tmp analysis.rule 2>/dev/null
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
cat $POTFILE | awk -F: '{print $NF}' | tee $tmp &>/dev/null

# Logic
if [ "$MACHINE" == "Mac" ]; then
    echo "This option is currently unavailable on Mac."
    source hash-cracker.sh
else
    python2 scripts/extensions/pack-linux/rulegen.py $tmp
    rm analysis-sorted.word analysis.word analysis-sorted.rule
fi

source scripts/selectors/wordlist.sh

$HASHCAT $KERNEL --bitmap-max=24 $HWMON $SHOWCRACKED --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST $WORDLIST -r analysis.rule $LOOPBACK
rm analysis.rule $tmp
echo -e "\nPACK rule processing done\n"