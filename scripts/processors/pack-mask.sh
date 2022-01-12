#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh

# Logic
$HASHCAT -O --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST --show | cut -d ':' -f2 | tee tmp_pwonly &>/dev/null
python2 scripts/extensions/pack/statsgen.py tmp_pwonly -o tmp_masks
python2 scripts/extensions/pack/maskgen.py tmp_masks --targettime 1000 --optindex -q --pps 14000000000 --minlength=2 -o tmp_hcmask
$HASHCAT -O --bitmap-max=24 --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a 3 tmp_hcmask
rm tmp_pwonly tmp_masks tmp_hcmask
echo -e "\n\e[32mPACK mask processing done\e[0m\n"