#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# Interrupt handling
trap 'processor_interrupt' INT TERM

# Logic
read_prompt "Please enter the full URL to spider (e.g. https://kb.offsec.nl): " URL "Unable to read the CeWL URL." || exit 1
read_prompt "Output name for the CeWL wordlist: " CEWLLIST "Unable to read the CeWL output path." || exit 1

read_prompt "Depth to spider to (0-9): " DEPTH "Unable to read the CeWL depth." || exit 1
while ! [[ "$DEPTH" =~ ^([0-9]|[1-9][0-9])$ ]]; do
    echo "Please only use 0-99."
    read_prompt "Depth to spider to (0-99): " DEPTH "Unable to read the CeWL depth." || exit 1
done

read_prompt "Minimum word length (1-9): " LENGTH "Unable to read the CeWL minimum word length." || exit 1
while ! [[ "$LENGTH" =~ ^([1-9]|[1-9][0-9])$ ]]; do
    echo "Please only use 1-99."
    read_prompt "Minimum word length (1-99): " LENGTH "Unable to read the CeWL minimum word length." || exit 1
done

echo -e "\nCeWL is going to start, this will take some time..."
echo -e "\nNOTE: If it takes to long, use CTRL+C to stop where CeWL is currently at, this will result in an output file.\n"

if dry_run_enabled; then
    dryrun_note "would run CeWL against $URL and write $CEWLLIST"
else
    if ! processor_run "$CEWL" -d "$DEPTH" -m "$LENGTH" -w "$CEWLLIST" "$URL" -u "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36"; then
        status_error "CeWL failed to generate a wordlist."
        exit 1
    fi
    processor_require_file "$CEWLLIST" "CeWL wordlist" || exit 1
fi

printf '\nCeWL created a wordlist named: %s\n\n' "$CEWLLIST"
