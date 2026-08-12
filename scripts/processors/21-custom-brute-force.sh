#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# Interrupt handling
trap 'processor_interrupt' INT TERM

# Requirements
processor_bootstrap

# Logic
TARGET=''
while true; do
    if ! read -r -p "Heavy lifting? How much chars are we going to brute-force? (1-99): " CHARS; then
        status_error "Unable to read the brute-force length."
        exit 1
    fi
    if [[ "$CHARS" =~ ^[0-9]+$ ]] && [ "$CHARS" -ge 1 ]; then
        COUNT="$CHARS"
        while [ "$COUNT" -gt 0 ]; do
            TARGET+="?a"
            COUNT=$((COUNT - 1))
        done
        break
    fi
    if [[ "$CHARS" =~ ^[0-9]+$ ]]; then
        echo "NO!"
    else
        printf '%s is not a number.\n' "$CHARS"
    fi
    status_error "Enter a positive numeric brute-force length."
done

while true; do
    if ! read -r -p "Enable increment? (y/n) " INCREMENT; then
        status_error "Unable to read the increment choice."
        exit 1
    fi
    case "$INCREMENT" in
        y)
            INCREMENT='--increment'
            break
            ;;
        n)
            INCREMENT=''
            break
            ;;
        *) status_error "Choose y or n for increment." ;;
    esac
done

hashcat_base -a3 "$TARGET" "$INCREMENT"

echo -e "\nCustom Brute Force Processing Done\n"
