#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# Requirements
processor_bootstrap
if [ "$MACHINE" == "Mac" ]; then
    mkpass_bin="${MKPASS_BIN:-scripts/extensions/mkpass-mac}"
else
    mkpass_bin="${MKPASS_BIN:-scripts/extensions/mkpass-linux}"
fi

# Rules
source scripts/rules/rules.config
RULELIST=("$rule3" "$rockyou30000" "$ORTRTS" "$fbfull" "$pantag" "$OUTD" "$techtrip2" "$TOXICSP" "$passwordpro" "$d3ad0ne" "$d3adhob0" "$generated2" "$toprules2020" "$hob064" "$leetspeak")

# Temporary Files
tmp=$(dryrun_tempfile markov-1)
tmp2=$(dryrun_tempfile markov-2)
trap 'processor_interrupt "$tmp" "$tmp2"' INT TERM
trap 'processor_cleanup "$tmp" "$tmp2"' EXIT

# Logic
while true; do
    if ! read -r -p "Use potfile (p) or wordlist (w): " LIST; then
        status_error "Unable to read the Markov source choice."
        exit 1
    fi
    if [ "$LIST" = 'p' ]; then
        LIST=$POTFILE
        break
    elif [ "$LIST" = 'w' ]; then
        source scripts/selectors/wordlist.sh
        LIST=$WORDLIST
        break
    fi
    echo -e "Try again...\n"
done

read -p "Minimum password (length) character limit: " NGRAM
read -p "Amount of passwords to create: " AMOUNT

if dry_run_enabled; then
    dryrun_note "would extract unique source words from $LIST into $tmp"
    if [ "$MACHINE" == "Mac" ]; then
        dryrun_note "would run mkpass-mac with ngram=$NGRAM amount=$AMOUNT into $tmp2"
    else
        dryrun_note "would run mkpass-linux with ngram=$NGRAM amount=$AMOUNT into $tmp2"
    fi
else
    if ! cat "$LIST" | awk -F: '{print $NF}' | sort -u | tee "$tmp" &>/dev/null; then
        status_error "Markov source extraction failed."
        exit 1
    fi
    if [ "$MACHINE" == "Mac" ]; then
        if ! "$mkpass_bin" -infile "$tmp" -ngram "$NGRAM" -m "$AMOUNT" | tee "$tmp2" &>/dev/null; then
            status_error "Markov helper failed."
            exit 1
        fi
    else
        if ! "$mkpass_bin" -infile "$tmp" -ngram "$NGRAM" -m "$AMOUNT" | tee "$tmp2" &>/dev/null; then
            status_error "Markov helper failed."
            exit 1
        fi
    fi
    processor_require_file "$tmp2" "Markov output" || exit 1
    rm -f -- "$tmp"
fi

while true; do
    if ! read -r -p "Use rules? (y/n): " USERULES; then
        status_error "Unable to read the Markov rules choice."
        exit 1
    fi
    if [[ $USERULES =~ ^[Yy]$ ]]; then
        for RULE in "${RULELIST[@]}"; do
            hashcat_base "$tmp2" -r "$RULE" "$LOOPBACK"
        done
        if ! dry_run_enabled; then
            rm -f -- "$tmp2"
        fi
        break
    elif [[ $USERULES =~ ^[Nn]$ ]]; then
        hashcat_base "$tmp2"
        if ! dry_run_enabled; then
            rm -f -- "$tmp2"
        fi
        break
    fi
    echo -e "Try again...\n"
done

echo -e "\nMarkov-chain processing done\n"
