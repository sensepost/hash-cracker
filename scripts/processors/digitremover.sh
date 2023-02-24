#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh

# Rules
source scripts/rules/rules.config
RULELIST=($fbfull $ORTRTS $NSAKEYv2 $techtrip2)

# Digitfilter
tmp=$(mktemp)
cat $POTFILE | cut -d: -f2- | grep -v '^\$HEX\[' | sed 's/[0-9]//g' | tee $tmp &>/dev/null
cat $POTFILE | cut -d: -f2- | grep '^\$HEX\[' | sed "s/\$HEX\[\(.*\)\]/\10a/" | xxd -r -ps | LC_ALL=C sed 's/[0-9]//g' | LC_ALL=C tee -a $tmp &>/dev/null

# Logic
$HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a6 $tmp -j c '?s?d?d?d?d' --increment
$HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a6 $tmp -j c '?d?d?d?d?s' --increment
$HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a6 $tmp -j c '?a?a' --increment
$HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a6 $tmp '?s?d?d?d?d' --increment
$HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a6 $tmp '?d?d?d?d?s' --increment
$HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a6 $tmp '?a?a' --increment

for RULE in ${RULELIST[*]}; do
    $HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST $tmp -r $RULE
done
rm $tmp
echo -e "\nDigit removal / Hybrid processing done\n"