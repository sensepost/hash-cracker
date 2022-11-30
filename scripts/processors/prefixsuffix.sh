#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh

# Logic
cat $POTFILE | awk -F: '{print $NF}' | tee tmp_prefixsuffix &>/dev/null
cat tmp_prefixsuffix | awk -F: '{print $NF}' | sort | tee tmp_passwords &>/dev/null && ./scripts/extensions/common-substr -n -p -f tmp_passwords > tmp_prefix && ./scripts/extensions/common-substr -n -s -f tmp_passwords > tmp_suffix && rm tmp_passwords tmp_prefixsuffix
$HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a1 tmp_prefix tmp_suffix
$HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a1 tmp_suffix tmp_prefix
rm tmp_prefix tmp_suffix; echo -e "\nPrefix suffix processing done\n"