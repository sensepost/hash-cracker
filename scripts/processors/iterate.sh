#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh

# Rules
source scripts/rules/rules.config
RULELIST=($rule3 $robotmyfavorite $fbfull $tenKrules $NSAKEYv2 $fordyv1 $pantag $OUTD $TOXICSP $techtrip2 $williamsuper $digits3 $dive $TOXIC10k $big $generated3 $huge)

# Logic
for RULE in ${RULELIST[*]}; do
    cat $POTFILE | awk -F: '{print $NF}' | sort -u | tee tmp_pwonly &>/dev/null
    $HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST tmp_pwonly -r $RULE --loopback
done
rm tmp_pwonly
echo -e "\nIteration processing done\n"