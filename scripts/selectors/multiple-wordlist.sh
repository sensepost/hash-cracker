#!/bin/bash
# Copyright crypt0rr
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
    read -e -p "Enter full path to second wordlist: " WORDLIST2
    if [ -f "$WORDLIST2" ]; then
    echo "Wordlist" $WORDLIST2 "selected."
    else
        echo "File does not exist, try again."; $RESTART
    fi
fi
