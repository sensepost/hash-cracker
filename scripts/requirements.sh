#!/bin/bash
# Copyright crypt0rr

# Requirements
HASHCAT=$(command -v hashcat)
POTFILE=(hash-cracker.pot)

# Logic
if ! [ -x "$(command -v $HASHCAT)" ]; then
    echo '[-] Hashcat is not installed or sourced in your profile'; ((COUNTER=COUNTER + 1))
else
    echo '[+] Hashcat is installed'
fi
if [[ -x "scripts/extensions/common-substr" ]]; then
    echo '[+] common-substr is executable'
else
    echo '[-] common-substr is not executable or found'; ((COUNTER=COUNTER + 1))
fi
if [[ -x "$(command -v python2)" ]]; then
    echo '[+] Python2 available'
else
    echo '[-] Python2 is not available but required for PACK'
fi
if [[ -x "scripts/extensions/hashcat-utils/bin/expander.bin" ]]; then
    echo '[+] expander is executable'
else
    echo '[-] expander is not available/executable or found, this is needed for fingerprint cracking'
fi
if test -f "$POTFILE"; then
    echo '[+] Potfile "hash-cracker.pot" present'
else
    echo '[-] Potfile not present, will create "hash-cracker.pot"'
    touch hash-cracker.pot
fi
if [ "$COUNTER" \> 0 ]; then
    echo -e "\nNot all mandatory requirements are met. Please fix and try again."; exit 1
fi
if [ "$NOP" == '-n' ] || [ "$NOP" == '--no-limit' ]; then
    echo "[-] Optimised kernels disabled"
    KERNEL=''
else
    echo "[+] Optimised kernels enabled"
    KERNEL='-O'
fi