#!/bin/bash
# Copyright crypt0rr

# Requirements
if [[ "$STATICCONFIG" = true ]]; then
    source hash-cracker.conf
else
    source scripts/selectors/hashtype.sh
    source scripts/selectors/hashlist.sh
fi

# Rules
source scripts/rules/rules.config
RULELIST=($tenKrules $NSAKEYv2 $fordyv1 $pantag $OUTD $techtrip2 $williamsuper $digits3 $dive)

# Cleanup
function clean_up {
    rm $tmp 2>/dev/null
    exit
}

trap clean_up SIGINT SIGTERM

# Temporary Files
tmp=$(mktemp /tmp/hash-cracker-tmp.XXXX)

# Logic
read -p "Enter a word (e.g. company name): " WORD
echo $WORD > $tmp
for RULE in ${RULELIST[*]}; do
    $HASHCAT $KERNEL --bitmap-max=24 $HWMON --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST $tmp -r $RULE $LOOPBACK
done
rm $tmp
echo -e "\nWord processing done\n"