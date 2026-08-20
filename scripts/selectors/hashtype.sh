#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/
TYPELIST="scripts/extensions/hashtypes"

while true; do
    if ! read -r -p "Enter hashtype (number): " HASHTYPE; then
        echo "Unable to read a hashtype."
        exit 1
    fi
    if [[ "$HASHTYPE" =~ ^[0-9]+$ ]] && grep -qiw -- "$HASHTYPE" "$TYPELIST"; then
        echo "Hashtype" "$(awk '{print $1,$2,$3}' "$TYPELIST" | grep -iw -- "$HASHTYPE")" "selected."
        break
    fi
    echo "Not a valid hashtype number, try again (https://hashcat.net/wiki/doku.php?id=example_hashes)"
done
