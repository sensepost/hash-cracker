#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh

# Single or multiple wordlist
read -p "Single or Multiple wordlist mode? S/M: " MODE

if [[ $MODE = [Ss] ]]; then
    source scripts/selectors/wordlist.sh
elif [[ $MODE = [Mm] ]]; then
    source scripts/selectors/multiple-wordlist.sh
fi

# Rules
source scripts/rules/rules.config
RULELIST=($tenKrules $NSAKEYv2 $fordyv1 $pantag $OUTD $techtrip2 $williamsuper $digits3 $dive $robotmyfavorite)

# Logic
$HASHCAT -O --bitmap-max=24 --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST $WORDLIST
for RULE in ${RULELIST[*]}; do
    $HASHCAT -O --bitmap-max=24 --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST $WORDLIST -r $RULE --loopback
done
echo -e "\nDefault processing with heavy rules done\n"