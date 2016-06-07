# mismas
A hodgepodge collection of various Unix scripts

## test-acl-bounderies.sh
Is a script that can be used on Linux, HPUX and Solaris to test how many ACLs can be defined on a test file or directory. It requires 1 parameter; an integer number that defines how many users/groups will be recreated and applied to that file. The `-c` removes all users and groups automatically.

##  count_files_per_dir.sh
Is an extreme simple script to show all directories from a given path (or current path if empty) and display the amount of files per directory, e.g.

    $ ./count_files_per_dir.sh  ~/bin
    Start from directory /home/gdhaese1/bin
    Directory /home/gdhaese1/bin contains 47 files
    
## fix-TLS-Logjam-vulnerability.sh
Is a script to scan and fix the OpenSSL LogJam issue in httpd.conf file. It works on HP-UX and Linux, but it should alos work on Solaris (untested).

## nanosleep.c
Is a simple C program to implement nanosleep intervals. The default value is 500 (=0.5 second) and it accepts a value between 1 and 999 (0.999 second or 1 second). It generates no output unless it detects an error then it shows the usage.

To compile use cc or gcc:

    $ cc nanosleep.c -o nanosleep

## timeout.c
A C program based on cratimeout.c, but using seconds as timeout values (instead of milleseconds). To compile use cc or gcc:

    $ cc -o timeout timeout.c

The usage is equivalent as of the timeout command on Linux:

    $ ./timeout 1 sleep 3
    Terminated
    $ echo $?
    143
    $ ./timeout 1 ls
    ...
    $ echo $?
    0
    $ ./timeout
    Usage: ./timeout seconds cmd args

## shrc.hpux
A shell script to change the prompt to something like (on HP-UX):

    [gdha@jupiter:/.root:160226.145608]

Date and timestamp automitically change per command executed, which is perfect in log files and for audit reasons.
In the `/etc/profile` script add `ENV=/etc/shrc.hpux ; export ENV` to activate it the next time you login.

## lan_monitoring.sh
Script for HP-UX systems only to assist in LAN cable migration tasks. Script was used during migration of CISCO switches and
with this script we were able to follow LAN status during the migration phase.

## make_rear_diskrestore_script.sh
Purpose of this script is to simulate the `rear recover` section
which creates the `/var/lib/rear/layout/diskrestore.sh` script.
It can be run on a production system and will not interfere with
anything. The output has been made safe if we run it by accident
so it does not overwrite your disk partition or wipe the boot disk.
However, consider this as a warning - handle with extreme care.
The output is meant for debugging purposes only (so you can see what
a recover would execute to recreate your boot disk layout).
Or, in case you are completely lost you can open an issue at
https://github.com/rear/rear/issues
But, if you expect an answer (on the diskrestore output) a rear
subscription, rear support contract or donation is required.
See details at http://relax-and-recover.org/support/sponsors

