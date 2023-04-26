#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh

# Rules
source scripts/rules/rules.config
RULELIST=($rule3 $robotmyfavorite $fbfull $tenKrules $NSAKEYv2 $fordyv1 $pantag $OUTD $TOXICSP $techtrip2 $williamsuper $digits3 $dive $TOXIC10k $big $generated3 $huge)

# Cleanup
function clean_up {
    rm $tmp 2>/dev/null
    exit
}

trap clean_up SIGINT SIGTERM

# Temporary Files
tmp=$(mktemp /tmp/hash-cracker-tmp.XXXX)

# Logic
for RULE in ${RULELIST[*]}; do
    cat $POTFILE | awk -F: '{print $NF}' | sort -u | tee $tmp &>/dev/null
    $HASHCAT $KERNEL --bitmap-max=24 $HWMON --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST $tmp -r $RULE $LOOPBACK
done
rm $tmp
echo -e "\nIteration processing done\n"