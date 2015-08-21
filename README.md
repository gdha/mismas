# mismas
A hodgepodge collection of various Unix scripts

## test-acl-bounderies.sh
Is a script that can be used on Linux, HPUX and Solaris to test how many ACLs can be defined on a test file or directory. It requires 1 parameter; an integer number that defines how many users/groups will be recreated and applied to that file. The `-c` removes all users and groups automatically.

##  count_files_per_dir.sh
Is an extreme simple script to show all directories from a given path (or current path if empty) and display the amount of files per directory, e.g.

    $ ./count_files_per_dir.sh  ~/bin
    Start from directory /home/gdhaese1/bin
    Directory /home/gdhaese1/bin contains 47 files
    

