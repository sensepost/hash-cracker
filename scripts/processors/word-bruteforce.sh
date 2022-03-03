#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh

# Logic
read -p "Enter a word (e.g. company name): " WORD
echo $WORD > tmp_word
$HASHCAT -O --bitmap-max=24 --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a6 tmp_word '?d?d?d?d?d?d?d?d' -i
$HASHCAT -O --bitmap-max=24 --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a6 tmp_word '?l?l?l?l?l?l' -i
$HASHCAT -O --bitmap-max=24 --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a7 '?d?d?d?d?d?d?d?d' tmp_word -i
$HASHCAT -O --bitmap-max=24 --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a7 '?l?l?l?l?l?l' tmp_word -i
$HASHCAT -O --bitmap-max=24 --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a6 tmp_word '?a?a?a?a' -i
$HASHCAT -O --bitmap-max=24 --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a7 '?a?a?a?a' tmp_word -i
rm tmp_word
echo -e "\nWord processing done\n"