#!/bin/bash
# Copyright crypt0rr
TYPELIST="scripts/extensions/hashtypes"

read -p "Enter search query: " QUERY
echo -e "\e[32m" && grep -i $QUERY $TYPELIST | sort -h
echo -e "\e[0m"