#!/bin/bash
#################################
# make_rear_diskrestore_script.sh
#################################
# License: GPLv3
# Author: Gratien D'haese (IT3 Consultants)
#
# Purpose of this script is to simulate the 'rear recover' section
# which creates the /var/lib/rear/layout/diskrestore.sh script.
# It can be run on a production system and will not interfere with
# anything. The output has been made safe if we run it by accident
# so it does not overwrite your disk partition or wipe the boot disk.
# However, consider this as a warning - handle with extreme care.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# The output is meant for debugging purposes only (so you can see what
# a recover would execute to recreate your boot disk layout).
# Or, in case you are completely lost you can open an issue at
# https://github.com/rear/rear/issues
# But, if you expect an answer (on the diskrestore output) a rear
# subscription, rear support contract or donation is required.
# See details at http://relax-and-recover.org/support/sponsors
############################################################################
readonly PRODUCT="Relax-and-Recover"
readonly PROGRAM=rear
readonly SCRIPT=${0##*/}
# Used in framework-functions.sh to calculate the time spent executing rear:
readonly STARTTIME=$SECONDS

# Provide the command line options in an array so that other scripts may read them:
readonly CMD_OPTS=( "$@" )

# Allow workflows to set the exit code to a different value (not "readonly"):
EXIT_CODE=0

# The default target mount point prefix
TARGET_FS_ROOT="/mnt/local"

# Are we root?
if test "$( id --user )" != "0" ; then
    echo "ERROR: $SCRIPT needs ROOT privileges!"
    exit 1
fi


# Find out if we're running from checkout
REAR_DIR_PREFIX=""
readonly SCRIPT_FILE="$( readlink -f $( type -p "$PROGRAM" || echo "$0" ) )"
if test "$SCRIPT_FILE" != "$( readlink -f /usr/sbin/$PROGRAM )" ; then
    REAR_DIR_PREFIX=${SCRIPT_FILE%/usr/sbin/$PROGRAM}
fi
readonly REAR_DIR_PREFIX

# Program directories - they must be set here. Everything else is then dynamic.
# Not yet readonly here because they are set via the /etc/rear/rescue.conf file
# in the recovery system that is sourced by the rear command in recover mode
# and CONFIG_DIR can also be changed via '-c' command line option:
SHARE_DIR="$REAR_DIR_PREFIX/usr/share/rear"
CONFIG_DIR="$REAR_DIR_PREFIX/etc/rear"
VAR_DIR="$REAR_DIR_PREFIX/var/lib/rear"
LOG_DIR="$REAR_DIR_PREFIX/var/log/rear"

if [[ ! -d $VAR_DIR ]] ; then
    echo "Is $PRODUCT really installed? Please check if $PROGRAM exists."
    exit 1
fi

# Generic global variables that are not meant to be configured by the user
# Perhaps we want to overrule the DISKLAYOUT_FILE variable as cmd arg? (FIXME)
DISKLAYOUT_FILE="$VAR_DIR/layout/disklayout.conf"

WORKFLOW="recover"

# Make sure that we use only English:
export LC_CTYPE=C LC_ALL=C LANG=C

# Include default config:
source $SHARE_DIR/conf/default.conf

# Include functions:
for script in $SHARE_DIR/lib/*.sh ; do
    source $script
done

mkdir -p $LOG_DIR
LOGFILE=$LOG_DIR/${SCRIPT%???}-$(date '+%Y%m%d-%H%M').log
exec 2>"$LOGFILE" || echo "ERROR: Could not create $LOGFILE" >&2

v=""
verbose=""
# Enable progress subsystem only in verbose mode, set some stuff that others can use:
if test "$VERBOSE" ; then
    v="-v"
    verbose="--verbose"
fi

# Enable debug output of the progress pipe
# (no readonly KEEP_BUILD_DIR because it is also set to 1 in build/default/98_verify_rootfs.sh):
test "$DEBUG" && KEEP_BUILD_DIR=1 || true

# Use this file to manually override the OS detection:
test -r "$CONFIG_DIR/os.conf" && Source "$CONFIG_DIR/os.conf" || true
test -r "$CONFIG_DIR/$WORKFLOW.conf" && Source "$CONFIG_DIR/$WORKFLOW.conf" || true
SetOSVendorAndVersion
# Distribution configuration files:
for config in "$ARCH" "$OS" \
        "$OS_MASTER_VENDOR" "$OS_MASTER_VENDOR_ARCH" "$OS_MASTER_VENDOR_VERSION" "$OS_MASTER_VENDOR_VERSION_ARCH" \
        "$OS_VENDOR" "$OS_VENDOR_ARCH" "$OS_VENDOR_VERSION" "$OS_VENDOR_VERSION_ARCH" ; do
    test -r "$SHARE_DIR/conf/$config.conf" && Source "$SHARE_DIR/conf/$config.conf" || true
done
# User configuration files, last thing is to overwrite variables if we are in the rescue system:
for config in site local rescue ; do
    test -r "$CONFIG_DIR/$config.conf" && Source "$CONFIG_DIR/$config.conf" || true
done
# Now SHARE_DIR CONFIG_DIR VAR_DIR LOG_DIR and KERNEL_VERSION should be set to a fixed value:
readonly SHARE_DIR CONFIG_DIR VAR_DIR LOG_DIR KERNEL_VERSION

if [[ ! -f "$DISKLAYOUT_FILE" ]]; then
   echo "You first need to run \"rear savelayout\" before"
   echo "you can make this script useful."
   echo "Got it? [press any key]" ; read junk
   exit 0
fi

echo "
##################################################################################
#       Starting $SCRIPT to produce layout code script
#       (for debugging purposes only)
#
#       Log file : $LOGFILE
#       date : $(date)
##################################################################################

"

#SourceStage "init"

#SourceStage "setup"

SourceStage "layout/prepare"

# never, never uncomment next line! It would wipe our your disk....Do NOT complain.
#SourceStage "layout/recreate"

[[ ! -f ${LAYOUT_CODE} ]] && exit 0

mv ${LAYOUT_CODE}  ${LAYOUT_CODE}.temp
cat > ${LAYOUT_CODE} <<EOF
#!/bin/bash
# Script $0 produced this ${LAYOUT_CODE} file
# It is meant as debugging aid - do not run it or edit it
# Gratien D'haese - gratien . dhaese @ gmail . com
# Copyright GPLv3
#
############################################################
#
echo "Script $0 produced ${LAYOUT_CODE} file"
echo "It is not meant to be executed - just to review the code"
echo "which recreates your disk layout (for debugging reasons)"
echo
echo "Force exit..."
exit 1
############################################################
############################################################
# Script ${LAYOUT_CODE} starts below
############################################################
############################################################
EOF

cat ${LAYOUT_CODE}.temp >>${LAYOUT_CODE}
rm -f ${LAYOUT_CODE}.temp

echo ""

echo "You can now check the script ${LAYOUT_CODE}"
echo "Do _not_ execute script ${LAYOUT_CODE}"

exit 0
