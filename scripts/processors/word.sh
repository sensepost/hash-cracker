#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh

# Rules
source scripts/rules/rules.config
RULELIST=($tenKrules $NSAKEYv2 $fordyv1 $pantag $OUTD $techtrip2 $williamsuper $digits3 $dive)

# Logic
read -p "Enter a word (e.g. company name): " WORD
echo $WORD > tmp_word
for RULE in ${RULELIST[*]}; do
    $HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST tmp_word -r $RULE --loopback
done
rm tmp_word
echo -e "\nWord processing done\n"