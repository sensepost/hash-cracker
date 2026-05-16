#!/bin/bash

if [ "$DRYRUN" = ' ' ]; then
    # shellcheck disable=SC2034
    HASHCAT='dry_run_hashcat'
fi
