#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# Requirements
if [[ "$STATICCONFIG" = true ]]; then
    source hash-cracker.conf
else
    source scripts/selectors/hashtype.sh
    source scripts/selectors/hashlist.sh
fi

# Single or multiple wordlist
read -p "Single or Multiple wordlist mode? S/M: " MODE

if [[ $MODE = [Ss] ]]; then
    source scripts/selectors/wordlist.sh
elif [[ $MODE = [Mm] ]]; then
    source scripts/selectors/multiple-wordlist.sh
fi

# Rules
source scripts/rules/rules.config
RULELIST=($rule3 $fbtop $toprules2020 $digits1 $digits2 $hob064 $leetspeak $toggles1 $toggles2 $OUTD)

# Logic
$HASHCAT $KERNEL --bitmap-max=24 $HWMON --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST $WORDLIST -r $stacking58 -r $stacking58 $LOOPBACK
for RULE in ${RULELIST[*]}; do
    $HASHCAT $KERNEL --bitmap-max=24 $HWMON --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST $WORDLIST -r $stacking58 -r $RULE $LOOPBACK
done
echo -e "\nStacking with light rules done\n"