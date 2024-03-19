#!/bin/bash

echo -e "\nOptional Modules:" 
if [[ -x "scripts/extensions/common-substr-linux" ]]; then
    echo '[+] common-substr-linux is executable'
else
    echo '[-] common-substr-linux is not available/executable (option 10 / 11)'
fi
if [[ -x "$(command -v python2)" ]]; then
    echo '[+] Python2 is executable'
else
    echo '[-] Python2 is not available/executable (option 12 / 13)'
fi
if [[ -x "scripts/extensions/hashcat-utils-linux/bin/expander.bin" ]]; then
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
