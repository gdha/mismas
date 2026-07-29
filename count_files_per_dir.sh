#!/bin/bash
# Script name: count_files_per_dir.sh
# Author: Gratien Dhaese

############# functions #################
function _show_usage {
    echo "Purpose $0: count the amount of files per directory"
    echo "Usage:    $0 [directory]"
}

function _count_files {
    if [[ $# -eq 1 ]] ; then
        # argument is a directory; use find to avoid fragile ls parsing
        find "$1" -maxdepth 1 -type f | wc -l
    else
        # no argument given
        echo 0
    fi
}

############## MAIN #####################
if [[ $# -eq 1 ]]; then
    StartPath="$1"
    if [[ ! -d "$StartPath" ]]; then
        echo "Argument $StartPath is not a directory!"
        _show_usage
        exit 1
    fi
else
    StartPath="$PWD"
fi

echo "Start from directory $StartPath"

find "$StartPath" -type d | while IFS= read -r DIRECTORY
do
    count=$(_count_files "$DIRECTORY")
    printf "Directory %s contains %s files\n" "$DIRECTORY" "$count"
done
