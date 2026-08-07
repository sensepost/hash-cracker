#!/bin/bash

# Optional dependencies are validated per selected menu option in hash-cracker.sh.
# shellcheck disable=SC2034
COMMON_SUBSTR_BIN="${COMMON_SUBSTR_BIN:-scripts/extensions/common-substr-linux}"
# shellcheck disable=SC2034
EXPANDER_BIN="scripts/extensions/hashcat-utils-linux/bin/expander.bin"

if [ -n "${CEWL:-}" ] && [ -x "$CEWL" ]; then
    :
elif command -v cewl >/dev/null 2>&1; then
    # shellcheck disable=SC2034
    CEWL=$(command -v cewl)
else
    # shellcheck disable=SC2034
    CEWL=''
fi
