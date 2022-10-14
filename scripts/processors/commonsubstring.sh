#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh

# Logic
cat $POTFILE | awk -F: '{print $NF}' | tee tmp_pwonly &>/dev/null > tmp_substring; rm tmp_pwonly
cat tmp_substring | awk -F: '{print $NF}' | sort | tee tmp_passwords &>/dev/null && ./scripts/extensions/common-substr -n -f tmp_passwords > tmp_allsubstrings && rm tmp_passwords tmp_substring
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a1 tmp_allsubstrings tmp_allsubstrings
rm tmp_allsubstrings; echo -e "\nSubstring processing done\n"; main