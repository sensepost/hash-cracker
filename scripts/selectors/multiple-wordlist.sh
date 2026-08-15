#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

function directory_has_entries() {
    local directory="$1"
    local entry

    [ -d "$directory" ] || return 1

    for entry in "$directory"/* "$directory"/.[!.]* "$directory"/..?*; do
        if [ -e "$entry" ] || [ -L "$entry" ]; then
            return 0
        fi
    done

    return 1
}

if ! [[ $START = '8' ]]; then
    while true; do
        if ! read -e -p "Enter path to a wordlist directory or a single wordlist file: " WORDLIST; then
            echo "Unable to read a wordlist path."
            exit 1
        fi
        if directory_has_entries "$WORDLIST"; then
            echo "Directory" "$WORDLIST" "selected."
            break
        elif [ -f "$WORDLIST" ]; then
            echo "Wordlist file" "$WORDLIST" "selected."
            break
        fi
        echo "Input must be a non-empty directory or an existing file, try again."
    done
fi

if [[ $START = '8' ]]; then
    if [[ "$STATICCONFIG" = true ]]; then
        if [ -f "$WORDLIST" ] && [ -f "$WORDLIST2" ]; then
            echo "Wordlist 1:" "$WORDLIST"
            echo "Wordlist 2:" "$WORDLIST2"
        else
            echo "Wordlist 1 and/or 2 does not exist, edit static configuration in 'hash-cracker.conf'."
            exit 1
        fi
    else
        while true; do
            if ! read -e -p "Enter full path to first wordlist: " WORDLIST; then
                echo "Unable to read the first wordlist path."
                exit 1
            fi
            if [ -f "$WORDLIST" ]; then
                echo "Wordlist" "$WORDLIST" "selected."
                break
            fi
            echo "File does not exist, try again."
        done
        while true; do
            if ! read -e -p "Enter full path to second wordlist: " WORDLIST2; then
                echo "Unable to read the second wordlist path."
                exit 1
            fi
            if [ -f "$WORDLIST2" ]; then
                echo "Wordlist" "$WORDLIST2" "selected."
                break
            fi
            echo "File does not exist, try again."
        done
    fi
fi
