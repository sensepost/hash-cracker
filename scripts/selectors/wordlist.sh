#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/
RESTART="source scripts/selectors/wordlist.sh"

if [[ "$STATICCONFIG" = true ]]; then
    if [ -f "$WORDLIST" ]; then
        echo "Wordlist" $WORDLIST "selected."
    else
        echo "Wordlist 1 does not exist, edit static configuration in 'hash-cracker.conf'."; exit
    fi
else
    read -e -p "Enter full path to wordlist: " WORDLIST
    if [ -f "$WORDLIST" ]; then
        echo "Wordlist" $WORDLIST "selected."
    else
        echo "File does not exist, try again."; $RESTART
    fi
fi