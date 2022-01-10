#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh

# Logic
$HASHCAT -O --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST --show > tmp_prefixsuffix
cat tmp_prefixsuffix | cut -d ':' -f2 | sort | tee tmp_passwords &>/dev/null && ./scripts/extensions/common-substr -n -p -f tmp_passwords > tmp_prefix && ./scripts/extensions/common-substr -n -s -f tmp_passwords > tmp_suffix && rm tmp_passwords tmp_prefixsuffix
$HASHCAT -O --bitmap-max=24 --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a1 tmp_prefix tmp_suffix
$HASHCAT -O --bitmap-max=24 --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a1 tmp_suffix tmp_prefix
rm tmp_prefix tmp_suffix; echo -e "\n\e[32mPrefix suffix processing done\e[0m\n"