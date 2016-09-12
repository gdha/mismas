#!/bin/ksh
# Script check_write_access.sh
# Author Gratien D'haese
# Usage: check_write_access.sh folder(dir)

set -A progress_chars \\ \| / -
progress_counter=-1

# check input parameter (if any)
if [[ -z "$1" ]] ; then
   WorkingDir=$(pwd)    # if no directory argument take current directory
elif [[ ! -d "$1" ]] ; then
   WorkingDir=$(pwd)    # argument was not a directory
else
   WorkingDir="$1"
fi
# if the WorkingDir ends with a / then the filename would be .csv
# To avoid this we jump to the WorkingDir and do pwd again to
# retrieve the directory name without ending /
cd $WorkingDir
WorkingDir=$(pwd)
cd -

filename=${WorkingDir##*/}.csv

case $(uname -s) in
    HP-UX) GETACL=getacl ;;
    *)     GETACL=getfacl ;;
esac

echo Start digging from directory $WorkingDir
echo Purpose is to create a CVS file containing all directories with their groups that have 'rwx' rights only

# write the header the the CSV file
echo "Directory,group,group,group," > $filename

# show some progress on the standard output
printf "-"
i=0
while (( $i < 100 )) ; do
    progress_counter=$(($progress_counter + 1))
    [[ $progress_counter -gt  3 ]] && progress_counter=0
    i=$(($i + 1))
    printf "\b${progress_chars[$progress_counter]}" 
done

progress_counter=-1
for DIR in $( find $WorkingDir -type d -exec ls -d {} \; 2>/dev/null )
do
   printf "%s" "$DIR," >>  $filename
   progress_counter=$(($progress_counter + 1))
   [[ $progress_counter -gt  3 ]] && progress_counter=0
   printf "\b${progress_chars[$progress_counter]}"  # print a dot the standard output to have some animation

   # remove everything that is not group related from getacl output and only keep 'rwx' entries
   $GETACL "$DIR" 2>/dev/null | grep -vE '(\#|default:|class:|owner:|user:|other:)' | grep rwx | while  IFS=":"  read f1 f2 f3
   do
       # Directory /export/DVL/data/GTSC/panaya/Archive
       # group::rwx
       # group:sapsys:rwx
       # group:gtdshrrw:rwx
       # group:gtdshrro:r-x
       if [[ "$f1" = "group" ]] ; then
           # should normally always be the case f1=group
	   if [[ "$f3" = "rwx" ]] && [[ ! -z "$f2" ]] ; then
               # f2=must contain a valid group and may not be empty AND f3=rwx
	       printf "%s" "$f2," >>  $filename
	       progress_counter=$(($progress_counter + 1))
	       [[ $progress_counter -gt  3 ]] && progress_counter=0
	       printf "\b${progress_chars[$progress_counter]}"
	   fi
       fi
   done
   printf "\n" >>  $filename

done
printf "\bSaved overview in $filename\n"
exit 0
