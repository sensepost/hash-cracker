#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/
if [[ "$STATICCONFIG" = true ]]; then
    if [ -f "$WORDLIST" ]; then
        echo "Wordlist" "$WORDLIST" "selected."
    else
        echo "Wordlist 1 does not exist, edit static configuration in 'hash-cracker.conf'."
        exit 1
    fi
else
    while true; do
        if ! read -e -p "Enter full path to wordlist: " WORDLIST; then
            echo "Unable to read a wordlist path."
            exit 1
        fi
        if [ -f "$WORDLIST" ]; then
            echo "Wordlist" "$WORDLIST" "selected."
            break
        fi
        echo "File does not exist, try again."
    done
fi
