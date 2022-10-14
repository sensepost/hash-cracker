#!/bin/bash
# Copyright crypt0rr

# Requirements
source scripts/selectors/hashtype.sh
source scripts/selectors/hashlist.sh

# Logic
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 '?a?a?a?a?a' --increment
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 '?l?l?l?l?l?l?l?l' --increment
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 '?u?u?u?u?u?u?u?u' --increment
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 '?d?d?d?d?d?d?d?d?d?d' --increment
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 '?1?1?1?1?1?1?1' -1 '?l?d?u' --increment
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 '?1?1?1?1?2?2?2?2?a' -1 '?l?u' -2 '?d' --increment
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 '?1?1?1?1?2?2?2?2' -1 '?d' -2 '?l?u' --increment
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 '?1?1?1?1?1?1?d?d' -1 '?l?u' -2 '?d' --increment
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 '?l?l?l?l?l?d?d?d?d' --increment
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 '?u?u?lul?u?d?d?d?d' --increment
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 '?l?l?l?l?l?d?d?d?d' --increment
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 '?u?u?u?u?u?d?d?d?d' --increment
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 '?l?l?l?l?l?l?d?d?d' --increment
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 '?u?u?u?u?u?u?d?d?d' --increment
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 '?d?d?d?d?d?l?l?l?l' --increment
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 '?d?d?d?d?d?u?u?u?u' --increment
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 '?l?l?d?d?d?d?d?d?d' --increment
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 '?u?u?d?d?d?d?d?d?d' --increment
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 '?l?l?d?d?d?d?l?l' --increment
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 '?u?u?d?d?d?d?u?u' --increment
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 '?l?d?d?l?d?d?l?d?d' --increment
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 '?u?d?d?u?d?d?u?d?d' --increment
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 '?d?d?d?d?d?d?d?d?l?l' --increment
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 '?d?d?d?d?d?d?d?d?u?u' --increment
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 '?d?d?l?d?d?l?d?d?l' --increment
$HASHCAT -O --bitmap-max=24 --hwmon-disable --potfile-path=$POTFILE -m$HASHTYPE $HASHLIST -a3 '?d?d?u?d?d?u?d?d?u' --increment
echo -e "\nmBrute force processing done\n"