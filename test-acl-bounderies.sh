#!/usr/bin/ksh
# Script Name: test-acl-bounderies.sh
# Author: Gratien D'haese
# Purpose: find the bounderies of ACLs on a directory/files
#
# $Revision:  $
# $Date:  $
# $Header:  $
# $Id:  $
# $Locker:  $
# History: Check the bottom of the file for revision history
# ----------------------------------------------------------------------------

PS4='$LINENO:=> ' # This prompt will be used when script tracing is turned on
typeset -x PRGNAME=${0##*/}                             # This script short name
typeset -x PRGDIR=${0%/*}                               # This script directory name
typeset -x PATH=$PATH:/usr/bin:/sbin:/usr/sbin:/usr/contrib/bin:
typeset -r platform=$(uname -s)                         # Platform
typeset dlog=/var/tmp                                   # Log directory
typeset instlog=$dlog/${PRGNAME%???}.log
typeset -r lhost=$(uname -n)                            # Local host name
typeset -r osVer=$(uname -r)                            # OS Release
typeset model=$(uname -m)                               # Model of the system
typeset today=$(date +'%Y-%m-%d.%H%M%S')
#
typeset -x LANG="C"
typeset -x LC_ALL="C"
typeset tcbdir=/tcb/files/auth
typeset mode=9999                                       # default 9999: dir/file permission mode
typeset ERRcode=0                                       # the exit code ERRcode will be used by send_test_event

# ----------------------------------------------------------------------------
#				DEFAULT VALUES
# ----------------------------------------------------------------------------
# default settings
#
# ----------------------------------------------------------------------------


[[ $PRGDIR = /* ]] || PRGDIR=$(pwd) # Acquire absolute path to the script

umask 022

# -----------------------------------------------------------------------------
#                                  FUNCTIONS
# -----------------------------------------------------------------------------
function _note {
        _echo "  -> $*"
} # Standard message display

function _helpMsg {
	cat <<eof
	Usage: $PRGNAME [-m <mail1,mail2>] [-c] [-dhv] integer
		-m: The mail recipients seperated by comma.
		-d: test ACLs out on a directory as well as on a file
		-c: cleanup all users and groups
		-h: This help message.
		-v: Revision number of this script.
		integer: integer number of how many users/groups to be created

 		By default ACLs will be tested on a file and it will be listed at the end
eof
}

function _print {
        printf "%4s %-80s: " "**" "$*"
}

function _ok {
        echo "[  OK  ]"
}

function _nok {
        ERRcode=$((ERRcode + 1))
        echo "[FAILED]"
}

function _na {
        echo "[  N/A ]"
}

function _line {
        echo "-----------------------------------------------------------------------------------------------"
} # draw a line

function _revision {
        typeset rev
        rev=$(awk '/Revision:/ { print $3 }' $PRGDIR/$PRGNAME | head -1 | sed -e 's/\$//')
        [ -n "$rev" ] || rev="UNKNOWN"
        echo $rev
} # Acquire revision number of the script and plug it into the log file

function _mail {
        [ -f "$instlog" ] || instlog=/dev/null
	[[ -z "$mailusr" ]] && return
        expand $instlog | mailx -s "$*" $mailusr
} # Standard email

function _echo {
        case $platform in
                Linux|Darwin) arg="-e " ;;
        esac

        echo $arg "$*"
} # echo is not the same between UNIX and Linux

function _error {
	_echo "ERROR: $*"
	echo
	exit 1
}

function _whoami {
        if [ "`whoami`" != "root" ]; then
                _error "$(whoami) - You must be root to run script $PRGNAME"
        fi
}

function is_digit {
	expr "$1" + 1 > /dev/null 2>&1	# sets the exit to non-zero if $1 non-numeric
}

function ExtractMode {
        # input: Directory or File name
        # output: mode in 4 numbers
        # Usage: ExtractMode ${Directory}|${File}
        # $mode contains real mode number
        #[ $mode -eq 9999 ] && continue
        typeset String
        String=`ls -ld $1 2>/dev/null | awk '{print $1}'`
        [ -z "${String}" ] && echo "$1 does not exist." && return
        Decode_mode "${String}"
        return $mode
}

function Decode_mode {
        # Purpose is to return the mode in decimal number
        # input: drwxrwxr-x (as an example)
        # return: 0775
        # error: 9999
        typeset StrMode
        StrMode=$1

        Partu="`echo $StrMode | cut -c2-4`"
        Partg="`echo $StrMode | cut -c5-7`"
        Parto="`echo $StrMode | cut -c8-10`"
	Parta="`echo $StrMode | cut -c11`"
        #echo "$Partu $Partg $Parto $Parta" 
        # Num and Sticky are used by function DecodeSubMode too
        Num=0
        Sticky=0
        # first decode the user part
        DecodeSubMode $Partu
        NumU=$Num
        Sticky_u=$Sticky
        # then decode the group part
        DecodeSubMode $Partg
        NumG=$Num
        Sticky_g=$Sticky
        # and finally, decode the other part
        DecodeSubMode $Parto
        NumO=$Num
        Sticky_o=$Sticky
        #echo "$NumU $Sticky_u $NumG $Sticky_g $NumO $Sticky_o"

        # put all bits together and calculate the mode in numbers
        sticky_prefix=$((Sticky_u * 4 + Sticky_g * 2 + Sticky_o))
        sticky_prefix=$((sticky_prefix * 1000))
        mode=$((NumU * 100 + NumG * 10 + NumO))
        mode=$((sticky_prefix + mode))
        return $mode
}

function DecodeSubMode {
        # input: String of 3 character (representing user/group/other mode)
        # output: integer number Num 0-7 and Sticky=0|1
        Sticky=0
        case $1 in
           "---") Num=0 ;;
           "--x") Num=1 ;;
           "-w-") Num=2 ;;
           "r--") Num=4 ;;
           "rw-") Num=6 ;;
           "r-x") Num=5 ;;
           "rwx") Num=7 ;;
           "--T") Num=0 ; Sticky=1 ;;
           "r-T") Num=4 ; Sticky=1 ;;
           "-wT") Num=2 ; Sticky=1 ;;
           "rwT") Num=6 ; Sticky=1 ;;
           "--t") Num=1 ; Sticky=1 ;;
           "r-t") Num=5 ; Sticky=1 ;;
           "-wt") Num=3 ; Sticky=1 ;;
           "rwt") Num=7 ; Sticky=1 ;;
           "--S") Num=0 ; Sticky=1 ;;
           "r-S") Num=4 ; Sticky=1 ;;
           "rwS") Num=6 ; Sticky=1 ;;
           "-wS") Num=2 ; Sticky=1 ;;
           "--s") Num=1 ; Sticky=1 ;;
           "r-s") Num=5 ; Sticky=1 ;;
           "rws") Num=7 ; Sticky=1 ;;
           "-ws") Num=3 ; Sticky=1 ;;
        esac
}

function _checkhpsmh {
        ExtractMode /opt/hpsmh
        if [ "${mode}" = "555" ]; then
                _print "Directory permissions of /opt/hpsmh ($mode)"
                _ok
        else
                _print "Directory permissions of /opt/hpsmh ($mode) should be 555"
                _nok
        fi
}


function _remove_account {
        grep -q "^${1}" /etc/passwd 2>&1
        if [ $? -ne 0 ]; then 
                _note "Local account \"${1}\" does not exist - did nothing"
        else    
                userdel -r ${1} && _note "Local account \"${1}\" has been successfully removed" || {
                   _error "Remove of account ${1} failed."
                   }
        fi
}

function _check_group {
        # parameter input $1: $group ; output: final group
	# only local group check!
        #_note "grep -q $1 /etc/group"
        grep -q "^$1:" /etc/group
        if [ $? -eq 0 ]; then
                return 0 # users is known
        else
                return 1
        fi
}

function _create_group {
	# parameter input $1: $group
	groupadd "$1"
	if [ $? -eq 0 ]; then
		_note "Local group \"$1\" has been successfully created" 
	else
		_error "Could not create local group \"$1\""
	fi
}

function _remove_group {
	# parameter input $1: $group
	groupdel "$1"
	if [ $? -eq 0 ]; then
		_note "Local group $1 has been successfully removed"
	else
		_error "Could not remove local group $1"
	fi
}

function _check_account {
        # parameter: local account name

        # _note grep ^${1} /etc/passwd
        grep -q "^${1}:" /etc/passwd 2>&1
        if [ $? -ne 0 ]; then
                return 1 # account does not exist
        else
                return 0
        fi
}

function _check_uid {
        # 1 parameter: uid - purpose is to check if uid is free, if not return value NOT
        cut -d: -f3 /etc/passwd | grep -q "$1" && return 0 || return 1
}

function _create_account {
        # 7 parameters: username password(encrypted) uid gid gecos home-dir shell
        # $3 is or " " (let system pick an uid) or is '-u $uid'
        case $platform in
                HP-UX)
                        useradd $3 -g "$4" -m -d "$6" -s "$7" -c "$5" "$1" || \
                                _error "Could not create $1 account."
                        /usr/lbin/modprpw -m exptm=0,lftm=0  "$1"       # no expiring
                        /usr/sam/lbin/usermod.sam -F -p "${2}" "$1"     # set pw
                        /usr/lbin/modprpw -v "$1"       # refresh pw
                        _note "Account $1 has been created successfully:"
                        /usr/lbin/getprpw  "$1"         # show details
                        ;;
                SunOS)
                        useradd $3 -g "$4" -m -d "$6" -s "$7" -c "$5" "$1" || \
                                _error "Could not create $1 account."
                        #passwd -r files -d "$1"        # should unlock the password, but NO
                        cp -p /etc/shadow /etc/shadow.sav
                        grep -v "^${1}" /etc/shadow > /tmp/shadow.lck
                        echo "${1}:${2}::14748:99999:15::::" >> /tmp/shadow.lck
                        chown root:sys /tmp/shadow.lck
                        chmod 400 /tmp/shadow.lck
                        mv -f /tmp/shadow.lck /etc/shadow
                        pwconv
                        case $? in
                                1) _error "pwconv: Permission denied" ;;
                                2) _error "pwconv: Invalid command syntax" ;;
                                3) _error "pwconv: Unexpected failure.  Conversion not done" ;;
                                4) _error "pwconv: Unexpected failure.  Password file(s) missing" ;;
                                5) _error "pwconv: Password file(s) busy.  Try again later" ;;
                                6) _error "pwconv: Bad entry in /etc/shadow file" ;;
                        esac
                        _note "Account $1 has been created successfully:"
                        passwd -s ${1}
                        ;;

                Linux)
                        useradd $3 -g "$4" -m -d "$6" -s "$7" -c "$5" -p "${2}" "$1" || \
                                _error "Could not create $1 account."
                        mkdir -p ${HDIR}
                        chown `grep "^${1}" /etc/passwd | cut -d: -f3` ${HDIR}
                        chgrp "$4" ${HDIR}
                        chmod 700 ${HDIR}
                        # make a system account - to be done
                        passwd  -n -1 -w -1 -x 99999 ${1}
                        chage -d $(echo $(( $(date +%s) / 86400 ))) ${1}
                        _note "Account $1 has been created successfully:"
                        # passwd -S ${1}
                        chage -l ${1}
                        ;;
        esac
}

function _check_dir_mode {
        # parameter: parent directory of users home directory, e.g. /home
        ExtractMode $1  # variable $mode contains permission mode in nrs.
        if [ "${mode}" -ne "755" ]; then
		chmod 755 $1 2>/dev/null
	  	_note "Reset permissions to 755 on $1"
        fi
}

function _protect_homedir {
        # parameter: home-directory
        [ -d $1 ] && chmod 700 $1
}

function _passwd_fields {
    #*****
    # prepare the pw, shell and home directory for ${1}
    PASSWORD="Z7oEJpHbNEAEw" # crypt algoryth test123 (openssl passwd -crypt)
    case $platform in
        HP-UX)  
                _check_dir_mode "/home"
                HDIR=/home/${1}
                (cd /home 2>/dev/null; df . ) | grep auto >/dev/null 2>/dev/null && HDIR=/${1}
                DSHELL=/usr/bin/sh
                ;;
        SunOS)  
                _check_dir_mode "/export/home"
                HDIR=/export/home/${1}
                (cd /export/home 2>/dev/null; df . ) | grep auto >/dev/null 2>/dev/null && HDIR=/${1}
                DSHELL=/bin/sh
                ;;
        Linux) 
                _check_dir_mode "/home"
                HDIR=/home/${1}
                (cd /home 2>/dev/null; df . ) | grep auto >/dev/null 2>/dev/null && HDIR=/${1}
                DSHELL=/bin/bash
                ;;
        *)      _note "Unsupported platform $platform"
                echo 999 >/tmp/EXITCODE
                exit 1
                ;;
    esac
    GECOS="$( printf user"%02d" $i ) - ACL test account"
}

function _set_user_acl {
    # input arguments: FILE User permissions
    case $platform in
        HP-UX)
               setacl -m user:"$2":"$3" "$1"
               [[ $? -eq 0 ]] && return 0 || return 1
               ;;
            *)
               setfacl -m user:"$2":"$3" "$1"
               [[ $? -eq 0 ]] && return 0 || return 1
               ;;
    esac
}

function _set_group_acl {
    # input arguments: FILE group permissions
    case $platform in
        HP-UX)
               setacl -m group:"$2":"$3" "$1"
               [[ $? -eq 0 ]] && return 0 || return 1
               ;;
            *)
               setfacl -m group:"$2":"$3" "$1"
               [[ $? -eq 0 ]] && return 0 || return 1
               ;;
    esac
}

function _show_acl {
    # input argument: file
    case $platform in
        HP-UX) getacl  "$1" ;;
            *) getfacl "$1" ;;
    esac
}

# -----------------------------------------------------------------------------
#				End of Functions
# -----------------------------------------------------------------------------



# -----------------------------------------------------------------------------
#				Default values
# -----------------------------------------------------------------------------
# are defined at the top of this script
typeset -i CLEANUP=0
typeset -i TEST_DIRECTORY=0

# -----------------------------------------------------------------------------
#				Config file
# -----------------------------------------------------------------------------

# ------------------------------------------------------------------------------
#                                   Analyse Arguments
# ------------------------------------------------------------------------------
while getopts ":m:dcvh" opt; do
	case "$opt" in
		m)	mailusr="$OPTARG"
			if [ -z "$mailusr" ]; then
				mailusr=root
			fi
			;;
		d)	TEST_DIRECTORY=1 ;;
		c)	CLEANUP=1 ;;
		v)	_revision; exit ;;
		h)	_helpMsg; exit 0 ;;
		\?)
			_note "$PRGNAME: unknown option used: [$OPTARG]."
			_helpMsg; exit 0
			;;
	esac
done
shift $(( OPTIND - 1 ))

MAXNR=$1
is_digit "$MAXNR" || MAXNR=0

if (( MAXNR == 0 )); then
    _helpMsg
    exit 1
fi


# -----------------------------------------------------------------------------
#				Sanity Checks
# -----------------------------------------------------------------------------
# check if LOG directory exists, if not, create it first
if [ ! -d $dlog ]; then
	_note "$PRGNAME ($LINENO): [$dlog] does not exist."
	_echo "     -- creating now: \c"
	mkdir -p $dlog && echo "[  OK  ]" || {
		echo "[FAILED]"
		_note "Could not create [$dlog]. Exiting now"
		exit 1
	}
fi

# ------------------------------------------------------------------------------
#					MAIN BODY
# ------------------------------------------------------------------------------

# before jumping into MAIN move the existing instlog to instlog.old
[ -f $instlog ] && mv -f $instlog ${instlog}.old

{
    _line
    echo "               Script: $PRGNAME"
    [[ "$(_revision)" = "UNKNOWN" ]] || echo "             Revision: $(_revision)"
    echo "       Executing User: $(whoami)"
    echo "     Mail Destination: $mailusr"
    echo "                 Date: $(date)"
    echo "                  Log: $instlog"
    _line; echo

    case $platform in
        HP-UX|Linux|SunOS) : ;; # OK
        *)
            _note "[$platform] is not supported by this script.\n"
            exit
            ;;
    esac



    _whoami         # only root can run this

    # The MAXNR defines the amount of users/groups we will be creating which will be
    # used to the the boundary limits of ACL which can be defined on a directory/file.
    # we will create user account in the trend of user01,...user${MAXNR}
    # we will also create unique group names for each user in the trend of group01..group${MAXNR}
    #
    # the -c option will clean up all created users/groups automatically
    # once the user/group are created we can test the ACLs

    # part 1: do the cleanup if requested with the -c option
    i=1
    if (( CLEANUP == 1 )) ; then
        while (( i <= $MAXNR )); do
            _check_account $( printf user"%02d" $i ) && _remove_account $( printf user"%02d" $i ) || \
		_note "User $( printf user"%02d" $i ) does not exist (skip step)"
            _check_group $( printf group"%02d" $i ) && _remove_group $( printf group"%02d" $i ) || \
		_note "Group $( printf group"%02d" $i ) does not exist (skip step)"
            i=$((i+1))
        done
        exit 0 # cleanup done; exit now
    fi

    # part 2: create the group; and user
    i=1
    while (( i <= $MAXNR )); do
        # first check group; and create it if needed
        _check_group $( printf group"%02d" $i ) && _note "Group $( printf group"%02d" $i ) exists (skip creation)" || \
             _create_group $( printf group"%02d" $i )
        _check_account $( printf user"%02d" $i ) && _note "User $( printf user"%02d" $i ) exists (skip creation)"  || \
             {
             _passwd_fields "$(printf user"%02d" $i)"
             _create_account "$(printf user"%02d" $i)" "${PASSWORD}" " " "$(printf group"%02d" $i)" "${GECOS}" "${HDIR}" "${DSHELL}"
             }
        i=$((i+1))
    done

    # part 3: define the ACLs on a testfile
    i=1
    FILE=./testfile
    [[ ! -f $FILE ]] && touch $FILE
    TEST_DIR=./testdir
    if (( TEST_DIRECTORY == 1 )) ; then
        [[ ! -d ./$TEST_DIR ]] && mkdir -p -m 755 $TEST_DIR
    fi
    _note "Starting with applying the ACLs..."
    while (( i <= $MAXNR )); do
        _set_user_acl $FILE $(printf user"%02d" $i) "rwx" || _error "Failed to define ACL of $(printf user"%02d" $i)"
        _set_group_acl $FILE $(printf group"%02d" $i) "r-x" ||  _error "Failed to define ACL of $(printf group"%02d" $i)"

        if (( TEST_DIRECTORY == 1 )) ; then
             _set_user_acl $TEST_DIR $(printf user"%02d" $i) "rwx" || _error "Failed to define ACL of $(printf user"%02d" $i)"
             _set_group_acl $TEST_DIR $(printf group"%02d" $i) "r-x" ||  _error "Failed to define ACL of $(printf group"%02d" $i)"
        fi
        i=$((i+1))
    done

    # part 4: show the test file acl
    echo
    _line
    _note "Show the ACLs on file $FILE"
    _show_acl $FILE

    if (( TEST_DIRECTORY == 1 )) ; then
        _line
        _note "Show the ACLs on directory $TEST_DIR"
        _show_acl $TEST_DIR
    fi


    echo
    _line
    echo "Finished with $ERRcode error(s)."
    _line
} 2>&1 | tee -a $instlog 2>/dev/null # tee is used in case of interactive run
[ $? -eq 1 ] && exit 1          # do not send an e-mail as non-root (no log file either)

_mail "Results of $PRGNAME (see also $instlog)"

# cleanup

# ----------------------------------------------------------------------------
# $Log:  $
#
#
# $RCSfile:  $
# $Source:  $
# $State: Exp $
# ----------------------------------------------------------------------------
