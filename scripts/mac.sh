#!/bin/bash

echo -e "\nOptional Modules:"
if [[ -x "scripts/extensions/common-substr-mac" ]]; then
    echo '[+] common-substr-mac is executable'
else
    echo '[-] common-substr-mac is not executable or found (option 10 / 11)'
fi
if [[ -x "scripts/extensions/hashcat-utils-mac/bin/expander.bin" ]]; then
    echo '[+] Expander is executable'
else
    echo '[-] Expander is not available/executable or found, this is needed for fingerprint cracking'
fi
if [[ -x "scripts/extensions/cewl/cewl.rb" ]]; then
    echo '[+] CeWL is executable'
    CEWL="scripts/extensions/cewl/cewl.rb"
else
    echo '[-] CeWL is not executable or found (option 18)'
fi