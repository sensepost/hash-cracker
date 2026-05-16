#!/bin/bash

# Optional dependencies are validated per selected menu option in hash-cracker.sh.
# shellcheck disable=SC2034
COMMON_SUBSTR_BIN="scripts/extensions/common-substr-mac"
# shellcheck disable=SC2034
EXPANDER_BIN="scripts/extensions/hashcat-utils-mac/bin/expander.bin"

if [[ -x "scripts/extensions/cewl/cewl.rb" ]]; then
    # shellcheck disable=SC2034
    CEWL="scripts/extensions/cewl/cewl.rb"
elif command -v cewl >/dev/null 2>&1; then
    # shellcheck disable=SC2034
    CEWL=$(command -v cewl)
else
    # shellcheck disable=SC2034
    CEWL=''
fi
