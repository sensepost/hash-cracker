#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh

# Logic
cat $POTFILE | awk -F: '{print $NF}' | sort -u | tee tmp_pwonly &>/dev/null
./scripts/extensions/hashcat-utils/bin/expander.bin < tmp_pwonly | sort -u > tmp_expanded && rm tmp_pwonly
$HASHCAT -O --bitmap-max=24 --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a 1 tmp_expanded tmp_expanded
rm tmp_expanded
echo -e "\nFingerprint attack done\n"