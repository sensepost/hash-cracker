#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh

# Rules
source scripts/rules/rules.config
RULELIST=($fbfull $ORTRTS $NSAKEYv2 $techtrip2 $generated3)

# Digitfilter
cat $POTFILE | awk -F: '{print $NF}' | sed 's/[0-9]//g' | tee tmp_digitfiltered &>/dev/null

# Logic
$HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a6 tmp_digitfiltered -j c '?s?d?d?d?d' --increment
$HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a6 tmp_digitfiltered -j c '?d?d?d?d?s' --increment
$HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a6 tmp_digitfiltered -j c '?a?a' --increment
$HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a6 tmp_digitfiltered '?s?d?d?d?d' --increment
$HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a6 tmp_digitfiltered '?d?d?d?d?s' --increment
$HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a6 tmp_digitfiltered '?a?a' --increment

for RULE in ${RULELIST[*]}; do
    $HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST tmp_digitfiltered -r $RULE
done
rm tmp_digitfiltered
echo -e "\nDigit removal / Hybrid processing done\n"