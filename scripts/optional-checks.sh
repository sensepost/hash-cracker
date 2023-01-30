#!/bin/bash
# Copyright crypt0rr

# Logic
if [[ -x "scripts/extensions/common-substr" ]]; then
    echo '[+] Common-substr is executable'
else
    echo '[-] Common-substr is not available/executable (option 10 / 11)'
fi
if [[ -x "$(command -v python2)" ]]; then
    echo '[+] Python2 is executable'
else
    echo '[-] Python2 is not available/executable (option 12 / 13)'
fi
if [[ -x "scripts/extensions/hashcat-utils/bin/expander.bin" ]]; then
    echo '[+] Expander is executable'
else
    echo '[-] Expander is not available/executable (option 14)'
fi
if [[ -x "$(command -v cewl)" ]]; then
    echo '[+] CeWL is executable'
    CEWL=$(command -v cewl)
else
    echo '[-] CeWL is not available/executable (option 18)'
fi

echo -e "\nKernel mode:"
if [ "$NOP" == '-n' ] || [ "$NOP" == '--no-limit' ]; then
    echo "[-] Optimised kernels disabled"
    KERNEL=''
else
    echo "[+] Optimised kernels enabled"
    KERNEL='-O'
fi