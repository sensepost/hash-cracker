#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

# Requirements
processor_bootstrap
common_substr_bin="${COMMON_SUBSTR_BIN:-scripts/extensions/common-substr-linux}"

# Temporary Files
tmp=$(dryrun_tempfile prefixsuffix)
tmp2=$(dryrun_tempfile prefixsuffix)
tmp3=$(dryrun_tempfile prefixsuffix)
tmp4=$(dryrun_tempfile prefixsuffix)
trap 'processor_interrupt "$tmp" "$tmp2" "$tmp3" "$tmp4"' INT TERM
trap 'processor_cleanup "$tmp" "$tmp2" "$tmp3" "$tmp4"' EXIT

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
        cat $tmp | awk -F: '{print $NF}' | sort | tee $tmp2 &>/dev/null && "$common_substr_bin" -n -p -f $tmp2 >$tmp3 && "$common_substr_bin" -n -s -f $tmp2 >$tmp4 && rm $tmp2 $tmp
    else
        cat $tmp | awk -F: '{print $NF}' | sort | tee $tmp2 &>/dev/null && "$common_substr_bin" -n -p -f $tmp2 >$tmp3 && "$common_substr_bin" -n -s -f $tmp2 >$tmp4 && rm $tmp2 $tmp
    fi
fi

hashcat_base -a1 $tmp3 $tmp4
hashcat_base -a1 $tmp4 $tmp3
if ! dry_run_enabled; then
    rm $tmp3 $tmp4
fi
echo -e "\nPrefix suffix processing done\n"
