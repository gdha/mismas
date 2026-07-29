#!/bin/bash
# Script: make-zero-files.sh
# Purpose: create small zero files (content is /dev/zero) which will be removed again at the end of this script.
# Reason is to have a file system that contains zero's (in un-used space) that is much better compressable.
# Author: Gratien D'haese
# Date: 14/Nov/2024
# License: GPLv3

# PS: check package "zerofree" which has the same purpose.

echo "
********************************************************************
**** [ $(date +'%F %H:%M:%S') ] Initiate script $(basename "$0") ****
********************************************************************
"

# Check if we are root
if [[ $(id -u) -ne 0 ]] ; then
   echo "script $(basename "$0") must be run as user \"root\""
   exit 1
fi

# Read filesystem mount points from /proc/mounts, safely handling spaces via read
while IFS= read -r line; do
    FS=$(echo "$line" | awk '{print $2}')
    [[ -z "$FS" ]] && continue

    # Check if current FS is read-only
    RO=0
    if echo "$line" | grep -q ' ro,'; then
        # File system is read-only; make it read-write for this operation
        RO=1
        echo "*** File system $FS remounting as read-write"
        mount -o remount,rw "$FS" || {
            echo "*** ERROR: Could not remount $FS as read-write, skipping."
            continue
        }
    fi

    echo "*** Creating zero files under file system $FS"
    i=1
    printf "*** Creating zerofile "
    while dd if=/dev/zero of="${FS}/zerofile.$i" bs=512k count=2k >/dev/null 2>&1; do
        printf "%s " "$i"
        i=$(( i + 1 ))
    done
    echo
    echo "Removing all zerofiles now..."
    rm -f "${FS}"/zerofile.*
    sleep 5

    if [[ $RO -eq 1 ]] ; then
        # Remount back as read-only file system
        echo "*** File system $FS remounting as read-only"
        mount -o remount,ro "$FS" || echo "*** WARNING: Could not remount $FS back as read-only"
    fi

done < <(grep '^/dev' /proc/mounts)

echo "
********************************************************************
**** [ $(date +'%F %H:%M:%S') ] Finished with $(basename "$0") ****
********************************************************************"
