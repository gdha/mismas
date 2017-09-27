#!/bin/bash

# script 
# Show all VM snapshots created per tier. This script communicates with NetBackup Data Domain.
#
# Script expects 1 argument: tier ($1) - tier is a group of hosts (as defined in an
# ansible inventory file (aka hosts file).
# The 'hosts' file is a copy of the ansible inventory file (and must be a local copy)

# Author: Gratien D'haese (c) 2017
# License: LGPL 3.0

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
if [[ ! -f $INVENTORY ]] ; then
    show_usage
    exit 1
fi

# Save the different tier names in a temporary file (/tmp/ansible.tiers)
# We will use that file to match a valid tier (from arg1)
grep "^\[" $INVENTORY  | sed -e 's/\[//' -e 's/]//'  >/tmp/ansible.tiers

# Check the 'required' argument (tier: group of hosts)
if [[ ! -z "$1" ]]; then
    tier=$1
else
    show_usage
    echo "Possible tiers are:"
    cat /tmp/ansible.tiers
    rm -f /tmp/ansible.tiers
    exit 1
fi

grep -q "$tier" /tmp/ansible.tiers
if [[ $? -eq 1 ]] ;then
    echo "Tier [$tier] not found in the inventory file. Possible tiers are:"
    cat /tmp/ansible.tiers
    rm -f /tmp/ansible.tiers
    exit 1
fi

# check it we have the require NBU binary to verify the VM snapshot creations time
if [[ ! -f /usr/openv/netbackup/bin/bpclimagelist ]] ; then
    echo "Executable /usr/openv/netbackup/bin/bpclimagelist not found."
    echo "If NetBackup Data Domain is not installed, please tell me what we should do"
    echo "Make an issue at https://github.com/gdha/mismas/issues"
    exit 1
fi

sed -n '1,/^\['$tier'\]/!{ /^\[.*\]/,/^\['$tier'\]/!p; }' $INVENTORY | while read system junk
do
   [[ -z "$system" ]] && continue
   echo "Checking VM snapshot made for system $system:"
   /usr/openv/netbackup/bin/bpclimagelist -client $system | head -5
   echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
done

# cleanup
rm -f /tmp/ansible.tiers
exit 0
