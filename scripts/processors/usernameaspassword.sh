#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh

# Rules
source scripts/rules/rules.config
RULELIST=($big)

# Logic
cat $HASHLIST | cut -d ':' -f1 | cut -d '\' -f2 > tmp_usernames
$HASHCAT -O --bitmap-max=24 --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST tmp_usernames
for RULE in ${RULELIST[*]}; do
    $HASHCAT -O --bitmap-max=24 --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST tmp_usernames -r $RULE --loopback
done
rm tmp_usernames; echo -e "\nUsername as Password processing with rules done\n"