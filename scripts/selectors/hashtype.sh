#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/
RESTART="source scripts/selectors/hashtype.sh"
TYPELIST="scripts/extensions/hashtypes"

read -p "Enter hashtype (number): " HASHTYPE
if [ -z "${HASHTYPE##*[!0-9]*}" ]; then
    echo "Not a valid hashtype number, try again (https://hashcat.net/wiki/doku.php?id=example_hashes)"; $RESTART
fi
if [ -z "$(grep -iw $HASHTYPE $TYPELIST)" ]; then
    echo "Not a valid hashtype number, try again (https://hashcat.net/wiki/doku.php?id=example_hashes)"; $RESTART
else
    echo "Hashtype" $(awk '{print $1,$2,$3}' $TYPELIST | grep -iw $HASHTYPE) "selected."
fi