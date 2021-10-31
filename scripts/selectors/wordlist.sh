#!/bin/bash
# Copyright crypt0rr
RESTART="bash scripts/selectors/wordlist.sh"

read -e -p "Enter full path to wordlist: " WORDLIST
if [ -f "$WORDLIST" ]; then
    echo -e "\e[32mWordlist" $WORDLIST "selected.\e[0m"
else
    echo -e "\e[31mFile does not exist, try again.\e[0m"; $RESTART
fi
if [[ $START = '9' ]]; then
    read -e -p "Enter full path to second wordlist: " WORDLIST2
    if [ -f "$WORDLIST" ]; then
    echo "\e[32mWordlist" $WORDLIST "selected.\e[0m"
    else
        echo -e "\e[31mFile does not exist, try again.\e[0m"; $RESTART
    fi
fi