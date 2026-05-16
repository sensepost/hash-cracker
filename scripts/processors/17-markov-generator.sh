#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

RESTART="source scripts/processors/17-markov-generator.sh"

# CTRL-C catch + cleanup of temp files
function clean_up {
    rm -f -- "$tmp" "$tmp2" 2>/dev/null
    exit 0
}

trap clean_up SIGINT SIGTERM

# Requirements
if [[ "$STATICCONFIG" = true ]]; then
    source hash-cracker.conf
    source scripts/runtime-overrides.sh
else
    source scripts/selectors/hashtype.sh
    source scripts/selectors/hashlist.sh
fi

# Rules
source scripts/rules/rules.config
RULELIST=("$rule3" "$rockyou30000" "$ORTRTS" "$fbfull" "$pantag" "$OUTD" "$techtrip2" "$TOXICSP" "$passwordpro" "$d3ad0ne" "$d3adhob0" "$generated2" "$toprules2020" "$hob064" "$leetspeak")

# Temporary Files
tmp=$(dryrun_tempfile markov)
tmp2=$(dryrun_tempfile markov)

# Logic
read -p "Use potfile (p) or wordlist (w): " LIST

if [ "$LIST" == 'p' ]; then
    LIST=$POTFILE
elif [ "$LIST" == 'w' ]; then
    source scripts/selectors/wordlist.sh
    LIST=$WORDLIST
else
    echo -e "Try again...\n"
    $RESTART
    exit 0
fi

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
    cat "$LIST" | awk -F: '{print $NF}' | sort -u | tee "$tmp" &>/dev/null
    if [ "$MACHINE" == "Mac" ]; then
        ./scripts/extensions/mkpass-mac -infile "$tmp" -ngram "$NGRAM" -m "$AMOUNT" | tee "$tmp2" &>/dev/null && rm -f -- "$tmp"
    else
        ./scripts/extensions/mkpass-linux -infile "$tmp" -ngram "$NGRAM" -m "$AMOUNT" | tee "$tmp2" &>/dev/null && rm -f -- "$tmp"
    fi
fi

read -p "Use rules? (y/n): " USERULES

if [[ $USERULES =~ ^[Yy]$ ]]; then
    for RULE in "${RULELIST[@]}"; do
        $HASHCAT $KERNEL --bitmap-max=24 -d $DEVICE $HWMON $SHOWCRACKED --potfile-path="$POTFILE" -m"$HASHTYPE" "$HASHLIST" "$tmp2" -r "$RULE" $LOOPBACK
    done
    if ! dry_run_enabled; then
        rm -f -- "$tmp2"
    fi
elif [[ $USERULES =~ ^[Nn]$ ]]; then
    $HASHCAT $KERNEL --bitmap-max=24 -d $DEVICE $HWMON $SHOWCRACKED --potfile-path="$POTFILE" -m"$HASHTYPE" "$HASHLIST" "$tmp2"
    if ! dry_run_enabled; then
        rm -f -- "$tmp2"
    fi
else
    echo -e "Try again...\n"
    $RESTART
    exit 0
fi

echo -e "\nMarkov-chain processing done\n"
