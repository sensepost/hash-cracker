#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh

# Cleanup
function clean_up {
    rm $tmp 2>/dev/null
    exit
}

trap clean_up SIGINT SIGTERM

# Temporary Files
tmp=$(mktemp /tmp/hash-cracker-tmp.XXXX)

# Logic
read -p "Enter a word (e.g. company name): " WORD
echo $WORD > $tmp
$HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a6 $tmp '?d?d?d?d?d?d?d?d' -i
$HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a6 $tmp '?l?l?l?l?l?l' -i
$HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a7 '?d?d?d?d?d?d?d?d' $tmp -i
$HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a7 '?l?l?l?l?l?l' $tmp -i
$HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a6 $tmp '?a?a?a?a' -i
$HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a7 '?a?a?a?a' $tmp -i
rm $tmp
echo -e "\nWord processing done\n"