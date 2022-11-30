#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh

# Logic
cat $POTFILE | awk -F: '{print $NF}' | sort -u | tee tmp_pwonly &>/dev/null
python2 scripts/extensions/pack/statsgen.py tmp_pwonly -o tmp_masks
python2 scripts/extensions/pack/maskgen.py tmp_masks --targettime 1000 --optindex -q --pps 14000000000 --minlength=2 -o tmp_hcmask
$HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a 3 tmp_hcmask
rm tmp_pwonly tmp_masks tmp_hcmask
echo -e "\nPACK mask processing done\n"