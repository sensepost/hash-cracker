#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh

# Rules
source scripts/rules/rules.config
RULELIST=($tenKrules $NSAKEYv2 $fordyv1 $pantag $OUTD $TOXICSP $techtrip2 $williamsuper $digits3 $dive $TOXIC10k $big $generated3 $huge)

# Logic
for RULE in ${RULELIST[*]}; do
    $HASHCAT -O --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST --show > tmp_output && cat tmp_output | cut -d ':' -f2 | sort -u | tee tmp_pwonly &>/dev/null; rm tmp_output
    $HASHCAT -O --bitmap-max=24 --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST tmp_pwonly -r $RULE --loopback
done
rm tmp_pwonly
echo -e "\nIteration processing done\n"