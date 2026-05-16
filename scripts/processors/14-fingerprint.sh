#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# Requirements
processor_bootstrap

# Temporary Files
tmp=$(dryrun_tempfile fingerprint)
tmp2=$(dryrun_tempfile fingerprint)
trap 'processor_interrupt "$tmp" "$tmp2"' INT TERM
trap 'processor_cleanup "$tmp" "$tmp2"' EXIT

# Logic
if dry_run_enabled; then
    dryrun_note "would extract unique plaintexts from $POTFILE to $tmp"
    if [ "$MACHINE" == "Mac" ]; then
        dryrun_note "would run hashcat-utils-mac expander.bin to produce $tmp2"
    else
        dryrun_note "would run hashcat-utils-linux expander.bin to produce $tmp2"
    fi
else
    cat $POTFILE | awk -F: '{print $NF}' | sort -u | tee $tmp &>/dev/null
    if [ "$MACHINE" == "Mac" ]; then
        ./scripts/extensions/hashcat-utils-mac/bin/expander.bin <$tmp | iconv -f ISO-8859-1 -t UTF-8//TRANSLIT | sort -u >$tmp2 && rm $tmp
    else
        ./scripts/extensions/hashcat-utils-linux/bin/expander.bin <$tmp | sort -u >$tmp2 && rm $tmp
    fi
fi

hashcat_base -a 1 $tmp2 $tmp2
if ! dry_run_enabled; then
    rm $tmp2
fi
echo -e "\nFingerprint attack done\n"
