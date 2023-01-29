#!/bin/bash
# Copyright crypt0rr

# Requirements
HASHCAT=$(command -v hashcat)
POTFILE=(hash-cracker.pot)

# Logic
if [[ -x "scripts/extensions/common-substr" ]]; then
    echo '[+] Common-substr is executable'
else
    echo '[-] Common-substr is not executable or found (option 10 / 11)'
fi
if [[ -x "$(command -v python2)" ]]; then
    echo '[+] Python2 available'
else
    echo '[-] Python2 is not available (option 12 / 13)'
fi
if [[ -x "scripts/extensions/hashcat-utils/bin/expander.bin" ]]; then
    echo '[+] Expander is executable'
else
    echo '[-] Expander is not available/executable or found (option 14)'
fi

echo -e "\nKernel mode:"
if [ "$NOP" == '-n' ] || [ "$NOP" == '--no-limit' ]; then
    echo "[-] Optimised kernels disabled"
    KERNEL=''
else
    echo "[+] Optimised kernels enabled"
    KERNEL='-O'
fi