# Simple script to rebase quickly my personal fork of rear to rear/rear/ master branch
# alias rebase='~/bin/rebase_myfork_rear.sh' in .bashrc
echo " Rebase my forked ReaR directory with the master rear/rear branch"
echo "=================================================================="
mydir="$HOME/projects/rear/myforks/rear"
cd $mydir
if [[ $? -ne 0 ]] ; then
   echo "Error: Directory $mydir not found - please update in script \$mydir variable"
   exit 1
fi

echo "
Show current branch - should be master"
git branch
echo "
Fetch upstream
"
git fetch upstream
echo "
Rebase now
"
git rebase upstream/master
echo "
Show status
"
git status
echo "
Push to my personal master fork of rear
"
git push origin master
echo "
==== Rebase with master-rear finished ===="
