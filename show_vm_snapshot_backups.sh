#!/bin/bash

# script 
# Show all VM snapshots created per tier. This script communicates with NetBackup Data Domain.
#
# Script expects 1 argument: tier ($1) - tier is a group of hosts (as defined in an
# ansible inventory file (aka hosts file).
# The 'hosts' file is a copy of the ansible inventory file (and must be a local copy)

# Author: Gratien D'haese (c) 2017
# License: GPL 3.0

# Variables
#----------
INVENTORY=$PWD/hosts      # default setting it looks for a hosts file in current directory
PROGRAM=${0##*/}

# Functions
#-----------
function show_usage ()
{
    echo "Usage: $PROGRAM [-i inventory] tier"
    echo "[tier] is the ansible group name found in an inventory file of ansible"
}

# MAIN
#-----

while getopts "i:h" opt; do
    case "$opt" in
        (i) INVENTORY="$OPTARG" ;;
        (h) show_usage; exit 0 ;;
    esac
done

shift $(( OPTIND - 1 ))

# Before going further verify if INVENTORY is found; if not show_usage and exit
if [[ ! -f "$INVENTORY" ]] ; then
    show_usage
    exit 1
fi

# Save the different tier names in a temporary file
TIERS_TMP=$(mktemp /tmp/ansible.tiers.XXXXXX)
grep "^\[" "$INVENTORY" | sed -e 's/\[//' -e 's/]//' > "$TIERS_TMP"

# Check the 'required' argument (tier: group of hosts)
if [[ -n "$1" ]]; then
    tier=$1
else
    show_usage
    echo "Possible tiers are:"
    cat "$TIERS_TMP"
    rm -f "$TIERS_TMP"
    exit 1
fi

# Escape any regex special characters in the tier name before passing to grep/sed
tier_escaped=$(printf '%s\n' "$tier" | sed 's/[.[\*^$]/\\&/g')

if ! grep -qF "$tier" "$TIERS_TMP"; then
    echo "Tier [$tier] not found in the inventory file. Possible tiers are:"
    cat "$TIERS_TMP"
    rm -f "$TIERS_TMP"
    exit 1
fi

# check if we have the required NBU binary to verify the VM snapshot creation time
if [[ ! -f /usr/openv/netbackup/bin/bpclimagelist ]] ; then
    echo "Executable /usr/openv/netbackup/bin/bpclimagelist not found."
    echo "If NetBackup Data Domain is not installed, please tell me what we should do"
    echo "Make an issue at https://github.com/gdha/mismas/issues"
    rm -f "$TIERS_TMP"
    exit 1
fi

sed -n '1,/^\['"$tier_escaped"'\]/!{ /^\[.*\]/,/^\['"$tier_escaped"'\]/!p; }' "$INVENTORY" | while IFS= read -r line
do
   # skip blank lines and lines starting with # or [
   system=$(echo "$line" | awk '{print $1}')
   [[ -z "$system" ]] && continue
   [[ "$system" == \[* ]] && continue
   [[ "$system" == \#* ]] && continue
   echo "Checking VM snapshot made for system $system:"
   /usr/openv/netbackup/bin/bpclimagelist -client "$system" | head -5
   echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
done

# cleanup
rm -f "$TIERS_TMP"
exit 0
