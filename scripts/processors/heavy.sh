#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh
source scripts/selectors/wordlist.sh

# Rules
source scripts/rules/rules.config
RULELIST=($tenKrules $NSAKEYv2 $fordyv1 $pantag $OUTD $techtrip2 $williamsuper $digits3 $dive)

# Logic
$HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST $WORDLIST
for RULE in ${RULELIST[*]}; do
    $HASHCAT -O --bitmap-max=24 -m$HASHTYPE $HASHLIST $WORDLIST -r $RULE --loopback
done
echo -e "\n\e[32mDefault processing with heavy rules done\e[0m\n"