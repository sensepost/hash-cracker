#!/bin/bash
# Copyright crypt0rr

# Requirements
HASHCAT=$(command -v hashcat)
POTFILE=(hash-cracker.pot)

# Logic
if ! [ -x "$(command -v $HASHCAT)" ]; then
    echo -e '\e[31m[-]' Hashcat  'is not installed or sourced in your profile\e[0m'; ((COUNTER=COUNTER + 1))
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
    echo -e '\e[33m[-]' 'Python2 is not available but required for PACK\e[0m'
fi
if [[ -x "scripts/extensions/hashcat-utils/bin/expander.bin" ]]; then
    echo -e '\e[32m[+]' 'expander is executable\e[0m'
else
    echo -e '\e[33m[-]' 'expander is not available/executable or found, this is needed for fingerprint cracking\e[0m'
fi
if test -f "$POTFILE"; then
    echo -e '\e[32m[+]' 'Potfile "hash-cracker.pot" present\e[0m'
else
    echo -e '\e[33m[-]' 'Potfile not present, will create "hash-cracker.pot"\e[0m'
    touch hash-cracker.pot
fi
if [ "$COUNTER" \> 0 ]; then
    echo -e "\n\e[31mNot all mandatory requirements are met. Please fix and try again."; exit 1
fi