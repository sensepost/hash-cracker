#!/bin/bash
# Copyright crypt0rr
TYPELIST="scripts/extensions/hashtypes"

read -p "Enter search query: " QUERY
echo -e "\e[34m" && grep -i $QUERY $TYPELIST
echo -e "\e[0m"