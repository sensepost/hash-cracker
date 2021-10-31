#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh

# Rules
source scripts/rules/rules.config
RULELIST=($tenKrules $NSAKEYv2 $fordyv1 $pantag $OUTD $techtrip2 $williamsuper $digits3 $dive)

# Logic
for RULE in ${RULELIST[*]}; do
    $HASHCAT -O -m$HASHTYPE $HASHLIST --show > tmp_output && cat tmp_output | cut -d ':' -f2 | sort -u | tee tmp_pwonly &>/dev/null; rm tmp_output
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST tmp_pwonly -r $RULE --loopback
done
rm tmp_pwonly
echo -e "\n\e[32mIteration processing done\e[0m\n"