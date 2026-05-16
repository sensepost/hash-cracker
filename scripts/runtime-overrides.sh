#!/bin/bash

if declare -F run_hashcat >/dev/null 2>&1; then
    # shellcheck disable=SC2034
    HASHCAT_BIN="$HASHCAT"
    # shellcheck disable=SC2034
    HASHCAT='run_hashcat'
fi
