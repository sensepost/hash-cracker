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
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST tmp_word -r $RULE --loopback
done
rm tmp_word
echo -e "\n\e[32mWord processing done\e[0m\n"