#!/bin/bash
# Copyright crypt0rr

# Requirements
HASHCAT="/usr/local/bin/hashcat"

# Logic
if ! [ -x "$(command -v $HASHCAT)" ]; then
    echo -e '\e[31m[-]' Hashcat  'is not installed or not in path (/usr/local/bin/hashcat)\e[0m'; ((COUNTER=COUNTER + 1))
else
    echo -e '\e[32m[+]' Hashcat 'is installed\e[0m'
fi
if [[ -x "scripts/extensions/common-substr" ]]; then
    echo -e '\e[32m[+]' 'common-substr is executable\e[0m'
else
    echo -e '\e[31m[-]' 'common-substr is not executable or found\e[0m'; ((COUNTER=COUNTER + 1))
fi
if [[ -x "$(command -v python2)" ]]; then
    echo -e '\e[32m[+]' 'Python2 available\e[0m'
else
    echo -e '\e[31m[-]' 'Python2 is not available but required for PACK\e[0m'
fi
if [ "$COUNTER" \> 0 ]; then
    echo -e "\n\e[31mNot all requirements are met. Please fix and try again."; exit 1
fi