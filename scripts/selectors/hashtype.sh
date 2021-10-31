#!/bin/bash
# Copyright crypt0rr
RESTART="bash scripts/selectors/hashtype.sh"
TYPELIST="scripts/extensions/hashtypes"

read -p "Enter hashtype (number): " HASHTYPE
if [ -z "${HASHTYPE##*[!0-9]*}" ]; then
    echo -e "\e[31mNot a valid hashtype number, try again (https://hashcat.net/wiki/doku.php?id=example_hashes)\e[0m"; $RESTART
else
    echo -e "\e[32mHashtype" $(awk '{print $1,$2,$3}' $TYPELIST | grep -iw $HASHTYPE) "selected.\e[0m"
fi