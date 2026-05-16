#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# CTRL-C catch + cleanup of temp files
function clean_up {
    rm $tmp $tmp2 $tmp3 $tmp4 2>/dev/null
    exit 0
}

trap clean_up SIGINT SIGTERM

# Requirements
if [[ "$STATICCONFIG" = true ]]; then
    source hash-cracker.conf
    source scripts/runtime-overrides.sh
else
    source scripts/selectors/hashtype.sh
    source scripts/selectors/hashlist.sh
fi

# Temporary Files
tmp=$(dryrun_tempfile prefixsuffix)
tmp2=$(dryrun_tempfile prefixsuffix)
tmp3=$(dryrun_tempfile prefixsuffix)
tmp4=$(dryrun_tempfile prefixsuffix)

# Logic
if dry_run_enabled; then
    dryrun_note "would extract plaintexts from $POTFILE to $tmp"
    if [ "$MACHINE" == "Mac" ]; then
        dryrun_note "would run common-substr-mac prefix/suffix generation into $tmp3 and $tmp4"
    else
        dryrun_note "would run common-substr-linux prefix/suffix generation into $tmp3 and $tmp4"
    fi
else
    cat $POTFILE | awk -F: '{print $NF}' | tee $tmp &>/dev/null
    if [ "$MACHINE" == "Mac" ]; then
        cat $tmp | awk -F: '{print $NF}' | sort | tee $tmp2 &>/dev/null && ./scripts/extensions/common-substr-mac -n -p -f $tmp2 >$tmp3 && ./scripts/extensions/common-substr-mac -n -s -f $tmp2 >$tmp4 && rm $tmp2 $tmp
    else
        cat $tmp | awk -F: '{print $NF}' | sort | tee $tmp2 &>/dev/null && ./scripts/extensions/common-substr-linux -n -p -f $tmp2 >$tmp3 && ./scripts/extensions/common-substr-linux -n -s -f $tmp2 >$tmp4 && rm $tmp2 $tmp
    fi
fi

hashcat_base -a1 $tmp3 $tmp4
hashcat_base -a1 $tmp4 $tmp3
if ! dry_run_enabled; then
    rm $tmp3 $tmp4
fi
echo -e "\nPrefix suffix processing done\n"
