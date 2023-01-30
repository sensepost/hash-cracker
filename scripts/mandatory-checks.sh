#!/bin/bash
# Copyright crypt0rr

# Requirements
HASHCAT=$(command -v hashcat)
POTFILE=(hash-cracker.pot)

# Logic
if ! [ -x "$(command -v $HASHCAT)" ]; then
    echo '[-] Hashcat is not available/executable'; ((COUNTER=COUNTER + 1))
else
    echo '[+] Hashcat is executable'
fi
if test -f "$POTFILE"; then
    echo '[+] Potfile "hash-cracker.pot" present'
else
    echo '[-] Potfile not present, will create "hash-cracker.pot"'
    touch hash-cracker.pot
fi
if [ "$COUNTER" \> 0 ]; then
    echo -e "\nNot all mandatory requirements are met. Please fix and try again."; exit 1
fi