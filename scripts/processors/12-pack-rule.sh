#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# Requirements
processor_bootstrap

# Temporary Files
tmp=$(dryrun_tempfile packrule)
pack_workdir="${tmp}.work"
pack_rule_path="$pack_workdir/analysis.rule"

pack_rule_cleanup() {
    processor_cleanup "$tmp" "$pack_rule_path"
    if [ -n "$pack_workdir" ] && ! campaign_path_preserved "$pack_rule_path"; then
        rm -rf -- "$pack_workdir"
    fi
}

trap 'processor_interrupt "$tmp" "$pack_rule_path"' INT TERM
trap pack_rule_cleanup EXIT
rulegen_path="scripts/extensions/pack-linux/rulegen.py"
if [ "$MACHINE" == "Mac" ]; then
    rulegen_path="scripts/extensions/pack-mac/rulegen.py"
fi
rulegen_absolute_path="$(cd "$(dirname "$rulegen_path")" && pwd)/$(basename "$rulegen_path")"

# Logic
if dry_run_enabled; then
    dryrun_note "would extract plaintexts from $POTFILE to $tmp"
    dryrun_note "would run python3 $rulegen_path $tmp in $pack_workdir"
else
    if ! cat "$POTFILE" | awk -F: '{print $NF}' | tee "$tmp" &>/dev/null; then
        status_error "PACK rule plaintext extraction failed."
        exit 1
    fi
    if ! mkdir -p "$pack_workdir"; then
        status_error "Unable to create the PACK rule work directory: $pack_workdir"
        exit 1
    fi
    if ! (cd "$pack_workdir" && python3 "$rulegen_absolute_path" "$tmp"); then
        status_error "PACK rule generation failed."
        exit 1
    fi
    processor_require_file "$pack_rule_path" "PACK rule output" || exit 1
fi

source scripts/selectors/wordlist.sh

hashcat_base "$WORDLIST" -r "$pack_rule_path" "$LOOPBACK"
if ! dry_run_enabled; then
    rm -f -- "$pack_rule_path" "$tmp"
fi
echo -e "\nPACK rule processing done\n"
