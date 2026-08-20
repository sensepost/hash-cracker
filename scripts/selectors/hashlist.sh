#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/
while true; do
    if ! read -r -e -p "Enter full path to hashlist: " HASHLIST; then
        echo "Unable to read a hashlist path."
        exit 1
    fi
    if [ -f "$HASHLIST" ]; then
        echo "Hashlist" "$HASHLIST" "selected."
        break
    fi
    echo "File does not exist, try again."
done
