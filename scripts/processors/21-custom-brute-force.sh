#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

RESTART="source scripts/processors/21-custom-brute-force.sh"

# CTRL-C catch
function clean_up {
    source hash-cracker.sh
}

trap clean_up SIGINT SIGTERM

# Requirements
if [[ "$STATICCONFIG" = true ]]; then
    source hash-cracker.conf
else
    source scripts/selectors/hashtype.sh
    source scripts/selectors/hashlist.sh
fi

# Logic
read -p "Heavy lifting? How much chars are we going to brute-force? (1-99): " CHARS
TARGET=''
[ -n "$CHARS" ] && [ "$CHARS" -eq "$CHARS" ] 2>/dev/null
if [ $? -ne 0 ]; then
    echo $CHARS is not a number.; $RESTART
elif [[ "$CHARS" < 1 ]]; then
        echo NO!; $RESTART
    else
        for i in $(seq 1 $CHARS); do
            TARGET+="?a"
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

$HASHCAT $KERNEL --bitmap-max=24 $HWMON $SHOWCRACKED --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 $TARGET $INCREMENT

echo -e "\nCustom Brute Force Processing Done\n"