#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

RESTART="source scripts/processors/21-custom-brute-force.sh"

# Interrupt handling
trap 'processor_interrupt' INT TERM

# Requirements
processor_bootstrap

# Logic
read -p "Heavy lifting? How much chars are we going to brute-force? (1-99): " CHARS
TARGET=''
[ -n "$CHARS" ] && [ "$CHARS" -eq "$CHARS" ] 2>/dev/null
if [ $? -ne 0 ]; then
    echo $CHARS is not a number.
    $RESTART
elif [ "$CHARS" -lt 1 ]; then
    echo NO!
    $RESTART
else
    COUNT="$CHARS"
    while [ "$COUNT" -gt 0 ]; do
        TARGET+="?a"
        COUNT=$((COUNT - 1))
    done
fi

read -p "Enable increment? (y/n) " INCREMENT

if [ "$INCREMENT" == 'y' ]; then
    INCREMENT='--increment'
elif [ "$INCREMENT" == 'n' ]; then
    INCREMENT=''
else
    $RESTART
fi

hashcat_base -a3 $TARGET $INCREMENT

echo -e "\nCustom Brute Force Processing Done\n"
