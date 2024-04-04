#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# CTRL-C catch + cleanup of temp files
function clean_up {
    rm $tmp 2>/dev/null
    source hash-cracker.sh
}

trap clean_up SIGINT SIGTERM

# Requirements
if [[ "$STATICCONFIG" = true ]]; then
    source hash-cracker.conf
else
    source scripts/selectors/hashtype.sh
    source scripts/selectors/hashlist.sh
fi

# Rules
source scripts/rules/rules.config
RULELIST=($big $fbfull $d3ad0ne $d3adhob0 $digits1 $digits2 $digits3 $dive $fordyv1 $generated2 $generated3 $hob064 $huge $leetspeak $NSAKEYv2 $ORTRTS $OUTD $pantag $passwordpro $rockyou30000 $techtrip2 $tenKrules $toggles1 $toggles2 $toprules2020 $TOXIC10k $TOXICSP $williamsuper)

# Temporary Files
tmp=$(mktemp /tmp/hash-cracker-tmp.XXXX)

# Logic
cat $HASHLIST | cut -d '\' -f2 | awk -F: '{print $1}' > $tmp
$HASHCAT $KERNEL --bitmap-max=24 $HWMON $SHOWCRACKED --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST $tmp
for RULE in ${RULELIST[*]}; do
    $HASHCAT $KERNEL --bitmap-max=24 $HWMON $SHOWCRACKED --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST $tmp -r $RULE $LOOPBACK
done
rm $tmp; echo -e "\nUsername as Password processing with rules done\n"