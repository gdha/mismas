#!/bin/bash
# Script: make-zero-files.sh
# Purpose: create small zero files (content is /dev/zero) which will be removed again at the end of this script.
# Reason is to have a file system that contains zero's (in un-used space) that is much better compressable.
# Author: Gratien D'haese
# Date: 14/Nov/2024
# License: GPLv3

# VARIABLES
FILESYSTEMS=$(cat /proc/mounts | grep '^/dev' | awk '{print $2}')

# MAIN
######

echo "
********************************************************************
**** [ $(date +'%F %H:%M:%S') ] Initiate script $(basename $0) ****
********************************************************************
"

# Check if we are root
if [[ $(id -u) -ne 0 ]] ; then
   echo "script $(basename $0) must be run as user \"root\""
   exit 1
fi

# Check if /dev/zero exists, if not create it
if [[ ! -c /dev/zero ]] ; then
   mknod /dev/zero c 1 5
   chmod 0666 /dev/zero
fi

for FS in $(echo $FILESYSTEMS)
do
   # Check if current FS is read-only and make it temporary read-write
   RO=0
   # Find FS (add extra space to avoid multiple times /)
   grep "${FS} " /proc/mounts | grep -q " ro,"
   if [[ $? -eq 0 ]] ; then
      # File system is read-only; make it read-write for this operation
      RO=1
      echo "*** File system $FS remounting as read-write"
      mount -o remount,rw ${FS}
   fi
   echo "*** Creating zero files under file system $FS"
   i=1
   printf "*** Creating zerofile "
   while dd if=/dev/zero of=${FS}/zerofile.$i bs=512k count=2k >/dev/null 2>&1; do printf "$i " ; i=$((i+1)); done
   echo
   echo "Removing all zerofiles now..."
   rm -f ${FS}/zerofile.*
   sleep 5
   if [[ $RO -eq 1 ]] ; then
      # Remount back as read-only file system
      echo "*** File system $FS remounting as read-only"
      mount -o remount,ro ${FS}
   fi
done
echo "
********************************************************************
**** [ $(date +'%F %H:%M:%S') ] Finished with $(basename $0) ****
********************************************************************"
