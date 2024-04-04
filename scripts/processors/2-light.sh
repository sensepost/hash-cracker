#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# CTRL-C catch
function clean_up {
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

# Single or multiple wordlist
read -p "Single or Multiple wordlist mode? S/M: " MODE

if [[ $MODE = [Ss] ]]; then
    source scripts/selectors/wordlist.sh
elif [[ $MODE = [Mm] ]]; then
    source scripts/selectors/multiple-wordlist.sh
fi

# Rules
source scripts/rules/rules.config
RULELIST=($rule3 $rockyou30000 $ORTRTS $fbtop $OUTD $TOXICSP $passwordpro $d3ad0ne $d3adhob0 $generated2 $toprules2020 $digits1 $digits2 $hob064 $leetspeak $toggles1 $toggles2)

# Logic
$HASHCAT $KERNEL --bitmap-max=24 $HWMON $SHOWCRACKED --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST $WORDLIST
for RULE in ${RULELIST[*]}; do
    $HASHCAT $KERNEL --bitmap-max=24 $HWMON $SHOWCRACKED --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST $WORDLIST -r $RULE $LOOPBACK
done
echo -e "\nDefault processing with light rules done\n"