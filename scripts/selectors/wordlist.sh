#!/bin/bash
# Copyright crypt0rr
RESTART="source scripts/selectors/wordlist.sh"

### If multiple checks needed use; if ! [[ $START = '15' || '1' ]]; for example

if ! [[ $START = '15' ]]; then
    read -e -p "Enter full path to wordlist: " WORDLIST
    if [ -f "$WORDLIST" ]; then
        echo "Wordlist" $WORDLIST "selected."
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
if [[ $START = '15' ]]; then
    read -e -p "Enter path to directory containing multiple wordlists: " WORDLIST
    if [ "$(ls -A $WORDLIST)" ]; then
    echo "Directory" $WORDLIST "selected."
    else
        echo "File does not exist, try again."; $RESTART
    fi
fi