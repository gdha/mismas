#!/usr/bin/ksh
# $Revision: 1.3 $
# ----------------------------------------------------------------------------

# Script: lan_monitoring.sh
# Purpose: See live what happens with the LANs and Link Aggregates during a migration of LAN cables
#		or upgrade of a Cisco IOS
#          Script will only run for HP-UX systems and will automatically detect APA trunks and SG

PS4='$LINENO:=> ' # This prompt will be used when script tracing is turned on
typeset -x PRGNAME=${0##*/}                             # This script short name
typeset -x PRGDIR=${0%/*}                               # This script directory name
typeset -x PATH=$PATH:/sbin:/usr/sbin                   # Setting up rudimentary path
typeset -r platform=$(uname -s)                         # Platform
typeset -r dlog=/var/adm/log				# Log directory

# If this is a one time SMS script, you might add date and time stamp
# to $instlog var name.  If you will run it repeatedly, I would not
# recommend doing it as you will end up with multiple log files
# (unless this is what you want).
typeset instlog=$dlog/${PRGNAME%???}.scriptlog

typeset -r lhost=$(uname -n)                            # Local host name
typeset -r osVer=$(uname -r)                            # OS Release
typeset model=$(uname -m)                               # Model of the system
typeset mailto="root"					# Mailing destination
typeset -x TZ=UTC                                       # Set time to UTC
typeset -x SGversion=					# Serviceguard version
typeset -x qs="n"					# SG with quorum server?
typeset -x lckdsk="n"					# SG with lock disk?
typeset -x HPAPA=${HPAPA:-n}				# if HPAPA has been set already take that value, otherwise n
typeset -x HPSG=${HPSG:-n}				# if HPSG (serviceguard) is predefined, keep that value
typeset -x LinkPro=MANUAL				# if HPAPA is used, which protocol is in use?
							# see hp_apaportconf for more details
typeset -x WARNLEVEL=0					# being optimistic

[[ $PRGDIR = /* ]] || PRGDIR=$(pwd) # Acquire absolute path to the script

# Integration tools know nothing about security and
# by default, anything they write is with 000 umask (big no, no)
umask 022

#############
# Functions #
#############

function _show_APA_links {
lanscan -q | awk 'NF > 1 {print}'| while read APA links
do
        lanscan | tr "A-Z" "a-z" | grep lan$APA | awk '{printf "%-7.7s %s\n", "lan" $3, $2}'
        for i in $links
        do
                printf "%-7.7s " lan$i
                echo "l\np\n$i\nd\nq\n" | lanadmin 2> /dev/null | awk '
                        /^Description /     {desc=$0}
                        /^Station Address / {print $NF, desc }'
        done
done
}

function _show_LAN_links {
	netstat -i | grep ^lan | grep -v :
}


function _check_LinkAgg {
	lanscan | grep LinkAgg | grep -q UP
	if [[ $? -eq 1 ]]; then
		_note "No HP APA Link Aggregates are active."
		HPAPA=n
	else
		_note "HP APA Link Aggregates are active."
		HPAPA=y
	fi
}

function _grab_LinkAgg_protocol {
	lanscan | grep LinkAgg | grep  UP | while read LAgr Mac LinkNr junk1 LinkInf junk2
	do
		LinkPro=$(lanadmin -x -i $LinkNr | grep "Link Aggregation Mode" | awk '{print $5}')
		_note "LinkAggregate $LAgr $LinkInf (MAC $Mac) is using $LinkPro"
	done
}

function _check_serviceguard_software {
	swlist | grep -iq serviceguard && HPSG=y || HPSG=n
}

function _check_cluster_defined {
	cmviewcl -v 2>/dev/null >/tmp/cmviewcl.txt || HPSG=n
}

function _check_lockdisk_or_qs_active {
	echo $(_surrounding_grep 0 3 'Quorum' /tmp/cmviewcl.txt) | head -3 | tail -1 | grep -q "up" && qs="y"
	echo $(_surrounding_grep 0 3 'Lock' /tmp/cmviewcl.txt) | head -3 | tail -1 | grep -q "up" && lckdsk="y"
}

function _surrounding_grep {
	# grep string ($3) in file $4 and print #lines before ($1) and #lines after ($2) the matched string ($3)
	typeset -i b=$1
	typeset -i a=$2
	typeset s="$3"
	fl=$4
	[[ ! -f $fl ]] && _error "Input file $fl not found"
	awk 'c-->0;$0~s{if(b)for(c=b+1;c>1;c--)print r[(NR-c+1)%b];print;c=a}b{r[NR%b]=$0}' b=$b a=$a s=$s $fl
}

function _line {
        typeset -i i
        while (( i < ${1:-80} )); do
                (( i+=1 ))
                _echo "-\c"
        done
        echo
} # draw a line

function _revision {
        typeset rev
        rev=$(awk '/Revision:/ { print $3 }' $PRGDIR/$PRGNAME | head -1)
        [ -n "$rev" ] || rev="UNKNOWN"
        echo $rev
} # Acquire revision number of the script and plug it into the log file

function _mail {
        [ -f "$instlog" ] || instlog=/dev/null
        mailx -s "$*" $mailto < $instlog
} # Standard email

function _echo {
        case $platform in
                Linux|Darwin) arg="-e " ;;
        esac

        echo $arg "$*"
} # echo is not the same between UNIX and Linux

function _note {
        _echo " ** $*"
} # Standard message display

function _highlight
{
        printf "$(tput smso) $* $(tput rmso) \n"
}

function _error {
	printf " *** ERROR: $* \n"
	exit 1
}

function _whoami {
        typeset wi
        case $platform in
                SunOS)
                        typeset wi=/usr/ucb/whoami
            if [ -x $wi ]; then
                $wi
            else
                wi=$(id); wi=${wi%%\)*}; wi=${wi#*\(}
                echo $wi
            fi
                ;;
                *) whoami ;;
        esac
}

function _date_time {
	_note "$(date '+%Y-%b-%d %H:%M:%S')"
}

function _count_lans {
	netstat -i | grep "^lan" | grep -v ":" | wc -l
}

function _SG_not_supported {
	echo
	_highlight "Warning: Serviceguard $SGversion is not supported anymore with $osVer"
	[[ "$LinkPro" = "FEC_AUTO" ]] && _highlight "Warning: HP APA $LinkPro not supported on Nexus routers (only LACP)"
	echo
	WARNLEVEL=$((WARNLEVEL + 1))
}

# -----------------------------------------------------------------------------
#                              Sanity Checks:
# -----------------------------------------------------------------------------
for i in $dlog; do
        if [ ! -d $i ]; then
                _note "$PRGNAME ($LINENO): [$i] does not exist."
                _echo "     -- creating now: \c"

                mkdir -p $i && echo "[  OK  ]" || {
                        echo "[FAILED]"
                        _note "Could not create [$i]. Exiting now"
                        exit 1
                }
        fi
done



# ------------------------------------------------------------------------------
#                                   MAIN BODY
# ------------------------------------------------------------------------------

os=${osVer#B.}	# 11.something
echo $os | grep -q "^11" || _error "Script $PRGNAME is only supported on HP-UX 11.*"

[[ "$(whoami)" != "root" ]] && _error "You must be root to run this script $PRGNAME"

{
_line
echo "               Script: $PRGNAME"
echo "             Revision: $(_revision)"
echo "                 Host: $lhost"
echo "                 User: $(_whoami)"
echo "                 Date: $(date)"
echo "                  Log: $instlog"
_line; echo


_check_LinkAgg			# $HPAPA should be set to y or n
if [[ "$HPAPA" = "y" ]]; then
	_grab_LinkAgg_protocol	# $LinkPro contains protocol (FEC_AUTO, LACP_AUTO, MANUAL or LM_MONITOR)
fi

_check_serviceguard_software	# when found set HPSG=y
if [[ "$HPSG" = "y" ]]; then
	# safety check (if only the software was installed, but no cluster has been set-up)
	_check_cluster_defined	# if no cluster defined or active then put HPSG=n ; generates output /tmp/cmviewcl.txt
fi
# SG cluster found
if [[ "$HPSG" = "y" ]]; then
	# source the SG main config file
	. /etc/cmcluster.conf
	# show message that we found an active cluster (and its name)
	[[ ! -f /tmp/cmviewcl.txt ]] && _error "Serviceguard /tmp/cmviewcl.txt output not found"
	printf " ** Found active Serviceguard cluster: "
	head -3 /tmp/cmviewcl.txt | tail -1 | awk '{print $1}'

	# check the APA protocol if used ($LinkPro)
	if [[ "$LinkPro" = "FEC_AUTO" ]]; then
		echo
		_highlight "Warning: Link Aggretation Protocol (PAgP) is not support on the Nexus router"
		_note "Please change PAgP into LACP as soon as possible (during downtime of cluster)"
		echo
		WARNLEVEL=$((WARNLEVEL + 1))
	fi

	# check SG version and which patch installed
	_note "Checking Serviceguard version and patch level..."
	SGversion=$(swlist | grep -E '(T1905BA|T1905CA|B3935DA)' | awk '{print $2}')
	SGpatch=$(show_patches | grep -i serviceguard | grep PHSS | tail -1 | awk '{print $1}')
	[[ -z "$SGpatch" ]] && SGpatch="none"
	_note "Serviceguard version $SGversion  - SG Patch $SGpatch"


	# check if a cluster brain situation can occur
	_check_lockdisk_or_qs_active
	if [ "$qs" = "n" ] && [ "$lckdsk" = "n" ]; then
		echo
		_highlight "Warning: Serviceguard: Could not find lock disk nor quorum server in \"cmviewcl -v\" output"
		echo
		WARNLEVEL=$((WARNLEVEL + 1))
	fi
	grep -iq "^SUBNET.*=" $SGCONF/*/*.script $SGCONF/*/*.config $SGCONF/*/*.conf 2>/dev/null
	if [[ $? -eq 0 ]]; then
		# PROBLEMS: SUBNET monitoring is ON with some packages [must be turned off]
		echo
		_highlight "Warning: Found packages where \"subnet monitoring\" is turned ON"
		_note "Please turn this OFF. Ask advice with Engineering."
		_note "These are the entries we found:"
		grep -i "^SUBNET.*=" $SGCONF/*/*.script $SGCONF/*/*.config $SGCONF/*/*.conf 2>/dev/null
		echo
		WARNLEVEL=$((WARNLEVEL + 1))
	fi
	rm -f /tmp/cmviewcl.txt		# cleanup
else
	# no SG cluster found
	_note "No Serviceguard cluster active."
fi

# Decision matrix
# HPAPA=[y|n]  HPSG=[y|n]
#
#	HPAPA		HPSG
#	  Y		 Y	APA bonding might drop in speed (1/2) or SG switches to APA fail-over
#	  Y		 N	APA LAN Monitor should switch to fail-over LAN interface
#	  N		 Y	SG should switch to stand-by LAN interface automatically
#	  N		 N	System unreachable during network upgrade/migration
#
if [[ "$HPAPA" = "n" ]] && [[ "$HPSG" = "n" ]]; then
	i=$(_count_lans)
	if [[ $i -eq 1 ]]; then
		echo
		_highlight "Warning: Only 1 LAN available - we will lose connectivity."
		echo
		WARNLEVEL=$((WARNLEVEL + 1))
	fi
fi

if [[ "$HPAPA" = "y" ]] && [[ "$HPSG" = "n" ]]; then
	if [[ "$LinkPro" = "LAN_MONITOR" ]]; then
		_note "HP APA $LinkPro is active, therefore, network connectivity is guaranteed."
	else
		_note "HP APA $LinkPro is active, but cannot guarantee LAN fail-over."
		i=$(_count_lans)
		if [[ $i -eq 1 ]]; then
			echo
			_highlight "Only 1 HP APA  available - we might lose connectivity."
			echo
			WARNLEVEL=$((WARNLEVEL + 1))
		fi
	fi
fi

if [[ "$HPAPA" = "n" ]] && [[ "$HPSG" = "y" ]]; then
	_note "HP Serviceguard will take care of LAN switch-over during the network outage."
fi

if [[ "$HPAPA" = "y" ]] && [[ "$HPSG" = "y" ]]; then
	# ok we must check patch level when HP APA's are used together with SG
	SGminnr=${SGversion#A.11.}		# A.11.16.00 => 16.00
	SGminnr=${SGminnr%.00}			# 16.00 => 16
	Patchnr=${SGpatch#PHSS_}
	[[ -z "$Patchnr" ]] && Patchnr=0	# make it an integer
	case "$os" in
	    "11.11")
			if [[ $SGminnr -lt 16 ]]; then
				_SG_not_supported
			else
				if [[ $Patchnr -lt 41822 ]]; then
					echo
					_highlight "Please install SG patch PHSS_41822 to support LACP"
					echo
					WARNLEVEL=$((WARNLEVEL + 1))
				fi
			fi
			;;
	    "11.23")	if [[ $SGminnr -lt 19 ]]; then
				_SG_not_supported
			else
				if [[ $Patchnr -lt 42987 ]]; then
					echo
					_highlight "Please install the latest SG patch PHSS_42897"
					echo
					WARNLEVEL=$((WARNLEVEL + 1))
				fi
			fi
			;;
	    "11.31")	if [[ $SGminnr -lt 19 ]]; then
				_SG_not_supported
			else
				if [[ $SGminnr -eq 19 ]] && [[ $Patchnr -lt 42988 ]]; then
					echo
					_highlight "Please install the latest SG patch PHSS_42988"
					echo
					WARNLEVEL=$((WARNLEVEL + 1))
				fi
				if [[ $SGminnr -eq 20 ]] && [[ $Patchnr -lt 43153 ]]; then
					echo
					_highlight "Please install the latest SG patch PHSS_43153"
					echo
					WARNLEVEL=$((WARNLEVEL + 1))
				fi
			fi
			;;
	esac
fi

if [[ $WARNLEVEL -gt 0 ]]; then
	echo
	_highlight "+---------------------------------------------------------------------+"
	_highlight "| Be aware that you might lose connectivity during the network outage |"
	_highlight "+---------------------------------------------------------------------+"
	echo
	echo "Press [enter] to continue or [control-C] to interrupt"
	read junk
fi

echo
_note "Script $(basename $0) will now start monitoring the LANs and will show"
_note "every 10 seconds the status."
_note "The output is saved in $instlog for your reference."
echo
_highlight "**** Press Cntrl-C to interrupt script $(basename $0) *****"
echo

while true
do
	_line
	_date_time
	[[ "$HPAPA" = "y" ]] && _show_APA_links || _show_LAN_links
	sleep 10
done

}  | tee $instlog

