#!/bin/bash
# Copyright crypt0rr
RESTART="bash scripts/selectors/hashlist.sh"

read -e -p "Enter full path to hashlist: " HASHLIST
if [ -f "$HASHLIST" ]; then
    echo -e "\e[32mHashlist" $HASHLIST "selected.\e[0m"
else
    echo -e "\e[31mFile does not exist, try again\e[0m"; $RESTART
fi