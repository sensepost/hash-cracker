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
RULELIST=($rule3 $robotmyfavorite $fbfull $tenKrules $NSAKEYv2 $fordyv1 $pantag $OUTD $TOXICSP $techtrip2 $williamsuper $digits3 $dive $TOXIC10k $big $generated3 $huge)

# Temporary Files
tmp=$(mktemp /tmp/hash-cracker-tmp.XXXX)

# Logic
for RULE in ${RULELIST[*]}; do
    cat $POTFILE | awk -F: '{print $NF}' | sort -u | tee $tmp &>/dev/null
    $HASHCAT $KERNEL --bitmap-max=24 $HWMON $SHOWCRACKED --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST $tmp -r $RULE $LOOPBACK
done
rm $tmp
echo -e "\nIteration processing done\n"