#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/
TYPELIST="scripts/extensions/hashtypes"

echo -e "\n"
read -p "Enter search query: " QUERY
grep -i $QUERY $TYPELIST | sort
echo -e "\n"