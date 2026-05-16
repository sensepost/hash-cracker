#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# CTRL-C catch
function clean_up {
    exit 0
}

trap clean_up SIGINT SIGTERM

# Requirements
if [[ "$STATICCONFIG" = true ]]; then
    source hash-cracker.conf
    source scripts/runtime-overrides.sh
else
    source scripts/selectors/hashtype.sh
    source scripts/selectors/hashlist.sh
fi
source scripts/selectors/multiple-wordlist.sh

# Rules
source scripts/rules/rules.config
RULELIST=("$ORTRTS")

# Logic
hashcat_base $WORDLIST
for RULE in "${RULELIST[@]}"; do
    hashcat_base $WORDLIST -r $RULE $LOOPBACK
done
echo -e "\nMultiple wordlists done\n"
