#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# CTRL-C catch
function clean_up {
    source hash-cracker.sh
}

trap clean_up SIGINT SIGTERM

# Logic
read -p "Please enter the full URL to spider (e.g. https://kb.offsec.nl): " URL
read -p "Output name for the CeWL wordlist: " CEWLLIST

read -p "Depth to spider to (0-9): " DEPTH
until [[ $DEPTH = [0-9] || [0-9][0-9] ]]; do
     echo "Please only use 0-99."
     read -p "Depth to spider to (0-99): " DEPTH
done

read -p "Minimum word length (1-9): " LENGTH
until [[ $LENGTH = [1-9] || [1-9][0-9] ]]; do
     echo "Please only use 1-99."
     read -p "Minimum word length (1-99): " LENGTH
done

echo -e "\nCeWL is going to start, this will take some time..."
echo -e "\nNOTE: If it takes to long, use CTRL+C to stop where CeWL is currently at, this will result in an output file.\n"

$CEWL -d $DEPTH -m $LENGTH -w $CEWLLIST $URL -u "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36"

echo -e "\nCeWL created a wordlist named:" $CEWLLIST "\n"