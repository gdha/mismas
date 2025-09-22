#!/usr/bin/env bash
# Script: alert.sh
# PURPOSE: send an alert to MS Teams PowerAutomate channel
# Author: Gratien D'haese
# Version: 1.0
# date: 22/Sep/2025

#############
# VARIABLES #
#############
PROGNAME="alert"
VERSION="1.0"
export LANG="en_US.UTF-8"    # make sure we use UTF-8 during text processing
HOSTNAME=$(/usr/bin/hostname)


CONFIG="/etc/alert.conf"
TITLE=""
BODY=""
FILE=""
# Generic logo of robot image:
IMAGE_URL="https://www.energise.co.nz/wp-content/uploads/2016/04/Prove-you-are-not-a-robot-and-digitalise-books-and-refine-maps.jpg"
# ReaR logo:
# IMAGE_URL="https://it3.be/images/logo/rear_logo_100.png"
WEBHOOK_URL=""

#############
# Functions #
#############

function show_usage ()
{
    # input value: exit code
    echo "Usage: alert [-e|--environment] tier [[-c|--config] configuration-file] [[-t|--title] \"TITLE line\"] [[-b|--body] \"body text\"] [[-f|--file] file for body text] [[-i|--image \"URL-of-picture\"]" 
    printf "\nAvailable options:\n"
    echo "-e|--environment  tier e.g. sandbox, developmnet, qa, uat or production (optional)"
    echo "-c|--config       configuration: is configuration file file (optional - default $CONFIG)"
    echo "-t|--title        title message (required)"
    echo "-b|--body         body text (optional when --file is used)"
    echo "-f|--file         read body text from file or stdin (required when --body is not used)"
    echo "-i|--image        Logo graph URL (optional)"
    echo "-h|--help         show usage (optional)"
    echo "-v|--version      show version (optional)"
    exit $1
}

function error
{
    printf " *** ERROR: $* \n"
    exit 1
}


##############################################
## M A I N                                   #
##############################################

umask 022

# Source the configuration file if it exists
# The config file should contain the settings WEBHOOK_URL and ENVIRONMENT
if [[ -f /etc/${PROGNAME}.conf ]]  ; then
    CONFIG="/etc/${PROGNAME}.conf"
fi



# Parse options
###############
# Examples at https://davetang.org/muse/2023/01/31/bash-script-that-accepts-short-long-and-positional-arguments/
help_note_text="Use '$PROGNAME --help' or 'man $PROGNAME' for more information."

if ! OPTS="$( getopt -n $PROGNAME -o "e:c:t:b:f:i:hv" -l "environment:,config:,title:,body:,file:,image:,help,version" -- "$@" )" ; then
    echo "$help_note_text"
    exit 1
fi
readonly OPTS
eval set --  "$OPTS"

while true ; do
    case "$1" in
        (-h|--help)
            show_usage 0          ;;
        (-v|--version)
            echo "$PROGNAME,v$VERSION"
            exit 0                ;;
        (-e|--environment)
            if [[ "$2" == -* ]] ; then
                echo "-e requires an argument."
                echo "$help_note_text"
                exit 1
            fi
            ENVIRONMENT="$2"
            shift                 ;;
        (-c|--config)
            if [[ "$2" == -* ]] ; then
                echo "-c requires an argument."
                echo "$help_note_text"
                exit 1
            fi
            CONFIG="$2"
            shift                 ;;
        (-t|--title)
            if [[ "$2" == -* ]] ; then
                echo "-T requires an argument."
                echo "$help_note_text"
                exit 1
            fi
            TITLE="$2"
            shift                 ;;
        (-b|--body)
            if [[ "$2" == -* ]] ; then
                echo "-b requires an argument."
                echo "$help_note_text"
                exit 1
            fi
            BODY="$2"
            shift                 ;;
        (-f|--file)
            if [[ "$2" == -* ]] ; then
                echo "-f requires an argument."
                echo "$help_note_text"
                exit 1
            fi
            FILE="$2"
            shift                 ;;
        (-i|--image)
            if [[ "$2" == -* ]] ; then
                echo "-i requires an argument."
                echo "$help_note_text"
                exit 1
            fi
            IMAGE_URL="$2"
            shift                 ;;
        (--)
            shift
            break                 ;;
        (-*)
            echo "$PROGNAME: unrecognized option '$1'"
            echo "$help_note_text"
            exit 1                ;;
        (*)
            break                 ;;
    esac
    shift
done

# Check the configuration file
if [[ -z "$CONFIG" ]] ; then
    show_usage 1
fi
if [[ ! -f "$CONFIG" ]] ; then
    error "$PROGNAME -c $CONFIG - configuration file $CONFIG not found"    
else
    source "$CONFIG"
fi

if [[ -z "$ENVIRONMENT" ]] ; then
    # Get the tier value to which this system belongs (sandbox, developmnt, qa , uat or production)
    # Most likely the /etc/tier file only exist on Treasury Linux systems.
    [[ -f /etc/tier ]] && ENVIRONMENT=$(cat /etc/tier)

    # When the ENVIRONMENT part was commented out in the configuration file we have the next block to rescue
    if [[ -z "$ENVIRONMENT" ]]; then
      [[ -x /bin/ohai ]] && ENVIRONMENT=$(/bin/ohai | grep -i scm_appbranch | cut -d\" -f4)
    fi
fi
if [[ -z "$ENVIRONMENT" ]] ; then
    error "$PROGNAME -e \"environment\" not set or not defined in $CONFIG"
fi
# Make sure that the ENVIRONMENT value is lowercase for the remaining part of this program
ENVIRONMENT="$( echo ${ENVIRONMENT,,} )"

if [[ -z "$TITLE" ]] ; then
    error "$PROGNAME -t \"title\" - missing title message"
fi

# When BODY variable is filled in then do not check FILE anymore
if [[ -n "$BODY" ]] ; then
    BODY="$(echo $BODY | sed -e 's/^/- /')"
elif [[ -n "$FILE" ]] ; then
    BODY="$( cat $FILE | sed -e 's/^/- /' -e 's/$/\\r\\r/'  )"
else
    echo "Reading from stdin..."
    BODY="$(cat - | sed -e 's/^/- /' -e 's/$/\\r\\r/'  )"
fi

# The BODY text may not contain " as it screw up JSON
BODY="$(echo $BODY | sed -e 's/"/:/g')"

color=Warning
HEADER="Alert on $(hostname -s) ($ENVIRONMENT)"
BOTTOM_MESSAGE="Message generated on system $(hostname -s) ($ENVIRONMENT: $(date '+%F'))"

JSON="{\"type\":\"message\",\"attachments\":[{\"contentType\":\"application/vnd.microsoft.card.adaptive\",\"contentUrl\":null,\"content\":{\"$schema\":\"http://adaptivecards.io/schemas/adaptive-card.json\",\"type\":\"AdaptiveCard\",\"version\":\"1.4\",\"body\":[{\"type\": \"ColumnSet\",\"columns\": [ { \"type\": \"Column\",\"targetWidth\": \"atLeast:narrow\",\"items\": [{\"type\": \"Image\",\"style\": \"Person\",\"url\": \"${IMAGE_URL}\",\"size\": \"Medium\"}], \"width\": \"auto\" }, { \"type\": \"Column\", \"spacing\": \"medium\", \"verticalContentAlignment\": \"center\", \"items\": [{\"type\": \"TextBlock\",\"text\": \"${HEADER}\",\"size\": \"ExtraLarge\",\"color\": \"${color}\"}],\"width\": \"auto\" }]},{ \"type\": \"TextBlock\", \"text\": \"${TITLE}\", \"weight\": \"bolder\", \"size\": \"Large\" },{\"type\": \"TextBlock\",\"text\": \"${BODY} \",\"wrap\": \"true\"},{\"type\": \"TextBlock\",\"text\": \"*${BOTTOM_MESSAGE}*\",\"wrap\": \"true\"}],\"msteams\": {\"width\": \"Full\"}}}]}"


/usr/bin/curl -H "Content-Type: application/json" -X POST -d "${JSON}" "${WEBHOOK_URL}" 2>/dev/null
