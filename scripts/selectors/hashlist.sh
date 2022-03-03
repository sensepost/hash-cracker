#!/bin/bash
# Copyright crypt0rr
RESTART="source scripts/selectors/hashlist.sh"

read -e -p "Enter full path to hashlist: " HASHLIST
if [ -f "$HASHLIST" ]; then
    echo "Hashlist" $HASHLIST "selected."
else
    echo "File does not exist, try again."; $RESTART
fi