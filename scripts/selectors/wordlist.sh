#!/bin/bash
# Copyright crypt0rr
RESTART="source scripts/selectors/wordlist.sh"

### If multiple checks needed use; if ! [[ $START = '15' || '1' ]]; for example

if ! [[ $START = '15' ]]; then
    read -e -p "Enter full path to wordlist: " WORDLIST
    if [ -f "$WORDLIST" ]; then
        echo -e "\e[32mWordlist" $WORDLIST "selected.\e[0m"
    else
        echo -e "\e[31mFile does not exist, try again.\e[0m"; $RESTART
    fi
fi
if [[ $START = '8' ]]; then
    read -e -p "Enter full path to second wordlist: " WORDLIST2
    if [ -f "$WORDLIST" ]; then
    echo "\e[32mWordlist" $WORDLIST "selected.\e[0m"
    else
        echo -e "\e[31mFile does not exist, try again.\e[0m"; $RESTART
    fi
fi
if [[ $START = '15' ]]; then
    read -e -p "Enter path to directory containing multiple wordlists: " WORDLIST
    if [ "$(ls -A $WORDLIST)" ]; then
    echo -e "\e[32mDirectory" $WORDLIST "selected.\e[0m"
    else
        echo -e "\e[31mFile does not exist, try again.\e[0m"; $RESTART
    fi
fi