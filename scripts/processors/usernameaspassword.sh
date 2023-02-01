#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh

# Rules
source scripts/rules/rules.config
RULELIST=($big $fbfull $d3ad0ne $d3adhob0 $digits1 $digits2 $digits3 $dive $fordyv1 $generated2 $generated3 $hob064 $huge $leetspeak $NSAKEYv2 $ORTRTS $OUTD $pantag $passwordpro $rockyou30000 $techtrip2 $tenKrules $toggles1 $toggles2 $toprules2020 $TOXIC10k $TOXICSP $williamsuper)

# Logic
cat $HASHLIST | cut -d '\' -f2 | awk -F: '{print $1}' > tmp_usernames
$HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST tmp_usernames
for RULE in ${RULELIST[*]}; do
    $HASHCAT $KERNEL --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST tmp_usernames -r $RULE --loopback
done
rm tmp_usernames; echo -e "\nUsername as Password processing with rules done\n"