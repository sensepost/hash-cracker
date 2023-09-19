#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/
RESTART="source scripts/selectors/multiple-wordlist.sh"

if ! [[ $START = '8' ]]; then
    read -e -p "Enter path to directory containing multiple wordlists: " WORDLIST
    if [ "$(ls -A $WORDLIST)" ]; then
    echo "Directory" $WORDLIST "selected."
    else
        echo "File does not exist, try again."; $RESTART
    fi
fi

if [[ $START = '8' ]]; then
    if [[ "$STATICCONFIG" = true ]]; then
        if [ -f "$WORDLIST" ] && [ -f "$WORDLIST2" ]; then
            echo "Wordlist 1:" $WORDLIST
            echo "Wordlist 2:" $WORDLIST2
        else
            echo "Wordlist 1 and/or 2 does not exist, edit static configuration in 'hash-cracker.conf'."; exit
        fi
    else
        read -e -p "Enter full path to first wordlist: " WORDLIST
        if [ -f "$WORDLIST" ]; then
            echo "Wordlist" $WORDLIST "selected."
        else
            echo "File does not exist, try again."; $RESTART
        fi
        read -e -p "Enter full path to second wordlist: " WORDLIST2
        if [ -f "$WORDLIST2" ]; then
            echo "Wordlist" $WORDLIST2 "selected."
        else
            echo "File does not exist, try again."; $RESTART
        fi
    fi
fi