#!/bin/bash

# The content of this file are licensed under the MIT License (https://opensource.org/licenses/MIT)
# MIT License
#
# Copyright (c) 2018 Paul Moss
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Delete files from a folder for a mega.nz account.
# Created by Paul Moss
# Created: 2018-05-27
# File Name: mega_del_old.sh
# Github: https://github.com/Amourspirit/mega_scripts
# Help: https://amourspirit.github.io/mega_scripts/mega_del_oldsh.html
#
# -p: Optional: -p pass in the full path directory to delete older files from Mega.nz. Default is "/Root"
# -a: Optional: -a pass in the number of days as a positive integer before todays date to delete files older then from Mega.nz. Default is 60 days.
# -i: Optional: i- pass in the configuration file to use that contain the credientials for the Mega.nz account you want to access
# -o: Optional: -o pass in the Log file to log to results of running mega_del_old.sh.
#     Can be value of "n" in which case results are outputed to the terminal window
#     Can be value of "s" in which case no results are written to a log file or terminal window.
#     Defaults to /var/log/mega_delete_old.log (requires script be run as root)
# -d: Optional: -d pass in the date of Log in the format of yyyy-mm-dd-hh-mm-ss. This will be used as the date stamp in the log file
#     Example: 2018-06-21-14-31-22
#     If -o is set to "s" this -d will be ignored.
# -v: Display the current version of this script
# -h: Display script help
#
# If this script is called from another script then having an option for log and log date makes it so the entries all have the same log date.
#
# Exit Codes
# Code  Defination
#   0   Normal Exit. No Errors Encountered.
#   3   No write privileges to create log file
#   4   Log file exist but no write privileges
#  10   Not a valid positve integer for -d option.
# 100   There is another mega process running. Can not continue.
# 101   megarm not found. Megtools requires installing
# 102   megals not found. Megtools requires installing
# 105   megadf not found. Megtools requires installing
# 111   Optional argument Param 3 was passed in but the config can not be found or we do not have read permissions

MS_VERSION='1.3.3.0'
# trims white space from input
function trim () {
    local var=$1;
    var="${var#"${var%%[![:space:]]*}"}";   # remove leading whitespace characters
    var="${var%"${var##*[![:space:]]}"}";   # remove trailing whitespace characters
    echo -n "$var";
}
LOG='/var/log/mega_del_old.log'
DATELOG=$(date +'%Y-%m-%d-%H-%M-%S')

# create an array that contains configuration values
# put values that need to be evaluated using eval in single quotes
typeset -A SCRIPT_CONF # init array
SCRIPT_CONF=( # set default values in config array
    [LOG_ID]='MEGA DELETE OLD:'
    [MAX_DAYS_DEFAULT]=60
    [LOG]="${LOG}"
    [MT_MEGA_LS]='megals'
    [MT_MEGA_RM]='megarm'
    [MT_MEGA_DF]='megadf'
)

# It is not necessary to have .mega_scriptsrc for this script
if [[ -f "${HOME}/.mega_scriptsrc" ]]; then
    # make tmp file to hold section of config.ini style section in
    TMP_CONFIG_FILE=$(mktemp)
    # SECTION_NAME is a var to hold which section of config you want to read
    SECTION_NAME="MEGA_DELETE_OLD"
    # sed in this case takes the value of SECTION_NAME and reads the setion from ~/config.ini
    sed -n '0,/'"$SECTION_NAME"'/d;/\[/,$d;/^$/d;p' "$HOME/.mega_scriptsrc" > $TMP_CONFIG_FILE

    # test tmp file to to see if it is greater then 0 in size
    test -s "${TMP_CONFIG_FILE}"
    if [ $? -eq 0 ]; then
    # read the input of the tmp config file line by line
        while read line; do
            if [[ "$line" =~ ^[^#]*= ]]; then
                setting_name=$(trim "${line%%=*}");
                setting_value=$(trim "${line#*=}");
                SCRIPT_CONF[$setting_name]=$setting_value
            fi
        done < "$TMP_CONFIG_FILE"
    fi
    # release the tmp file that is contains the current section values
    unlink $TMP_CONFIG_FILE
fi

#  read the folder into a var
MEGA_DEFAULT_ROOT="/Root"
MAX_DAYS_DEFAULT=${SCRIPT_CONF[MAX_DAYS_DEFAULT]}
LOG=$(eval echo ${SCRIPT_CONF[LOG]})
LOG_ID=${SCRIPT_CONF[LOG_ID]}
FILE_COUNT=0
FILE_COUNT_DELETED=0
LOCK_FILE="/tmp/mega_del_old_lock"
CURRENT_MEGA_FOLDER=""
CURRENT_CONFIG=''
CURRENT_SPACE=''
MAX_AGE=''
MEGA_FILES=''
IN_ROOT=0
MEGA_SERVER_PATH=''
HAS_CONFIG=0
MT_MEGA_LS=${SCRIPT_CONF[MT_MEGA_LS]}
MT_MEGA_RM=${SCRIPT_CONF[MT_MEGA_RM]}
MT_MEGA_DF=${SCRIPT_CONF[MT_MEGA_DF]}

MT_MEGA_LS=$(eval echo ${MT_MEGA_LS})
MT_MEGA_RM=$(eval echo ${MT_MEGA_RM})
MT_MEGA_DF=$(eval echo ${MT_MEGA_DF})

usage() { echo "$(basename $0) usage:" && grep "[[:space:]].)\ #" $0 | sed 's/#//' | sed -r 's/([a-z])\)/-\1/'; exit 0; }
while getopts ":hvp:a:o:d:i:" arg; do
  case $arg in
    p) # Optional: Specify -p the full path directory to delete older files from Mega.nz.
        MEGA_SERVER_PATH="${OPTARG}"
        ;;
    a) # Optional: Specify -a for age that represents the number of days as a positive integer before todays date to delete files older then from Mega.nz.
        MAX_DAYS_DEFAULT="${OPTARG}"
        ;;
    i) # Optional: Specify -i the configuration file to use that contain the credentials for the Mega.nz account you want to access.
        CURRENT_CONFIG="${OPTARG}"
        ;;
    o) # Optional: Specify -o the output option Default log. Can be t for terminal. Can be s for silent
        LOG="${OPTARG}"
        ;;
    d) # Optional: Specify -d Date of Log in the format of yyyy-mm-dd-hh-mm-ss. This will be used as the date stamp in the log file. Example: 2018-06-21-14-31-22
        DATELOG="${OPTARG}"
        ;;
    v) # -v Display version info
        echo "$(basename $0) version:${MS_VERSION}"
        exit 0
        ;;
    h) # -h Display help.
        echo 'For online help visit: https://amourspirit.github.io/mega_scripts/mega_del_oldsh.html'
        usage
        exit 0
        ;;
  esac
done

# the follow vars are eval in case they contain other expandable vars such as $HOME or ${USER}
LOG=$(eval echo ${LOG})
CURRENT_CONFIG=$(eval echo ${CURRENT_CONFIG})

if [[ -n "${LOG}" ]]; then
    if [[ "${LOG}" = 't' ]]; then
        # redirect to terminal output
        LOG=/dev/stdout
    elif [[ "${LOG}" = 's' ]]; then
        # redirect to null output
        LOG=2>/dev/null
    else
        # test to see if the log exits
        if [[ -f "${LOG}" ]]; then
            # log does exist
            # see if we have write access to it
            if ! [[ -w "${LOG}" ]]; then
                # no write access to log file
                # exit with error code 3
                echo "No write access log file '${LOG}'. Ensure you have write privileges. Exit Code: 3"
                exit 3
            fi
        else
            # log does not exist see if we can create it
            mkdir -p "$(dirname ${LOG})"
            if [[ $? -ne 0 ]]; then
                # unable to create log
                # exit with error code 4
                echo "Unable to create log file '${LOG}'. Ensure you have write privileges. Exit Code: 4"
                exit 4
            fi
            touch "${LOG}"
            if [[ $? -ne 0 ]]; then
                # unable to create log
                # exit with error code 4
                echo "Unable to create log file '${LOG}'. Ensure you have write privileges. Exit Code: 4"
                exit 4
            fi
        fi
    fi
fi

# if log is not supplied then redirect to stdout
if [[ -z $LOG ]]; then
  LOG=/dev/stdout
fi

# https://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
if ! [ -x "$(command -v ${MT_MEGA_RM})" ]; then
    echo "${DATELOG} ${LOG_ID} You have not enabled MEGA remove." >> ${LOG}
    echo "${DATELOG} ${LOG_ID} You need to install megatools from http://megatools.megous.com or properly configure .mega_scriptsrc to point to the megarm location! Exit Code: 101" >> ${LOG}
    echo "${DATELOG} ${LOG_ID} MEGA remove failed" >> ${LOG}
    exit 101
fi
if ! [ -x "$(command -v ${MT_MEGA_LS})" ]; then
    echo "${DATELOG} ${LOG_ID} You have not enabled MEGA list." >> ${LOG}
    echo "${DATELOG} ${LOG_ID} You need to install megatools from http://megatools.megous.com or properly configure .mega_scriptsrc to point to the megals location! Exit Code: 102" >> ${LOG}
    echo "${DATELOG} ${LOG_ID} MEGA list failed" >> ${LOG}
    exit 102
fi
if ! [ -x "$(command -v ${MT_MEGA_DF})" ]; then
    echo "${DATELOG} ${LOG_ID} You have not enabled MEGA Storage usage." >> ${LOG}
    echo "${DATELOG} ${LOG_ID} You need to install megatools from http://megatools.megous.com or properly configure .mega_scriptsrc to point to the megadf location! Exit Code: 105" >> ${LOG}
    echo "${DATELOG} ${LOG_ID} MEGA storage usage failed" >> ${LOG}
    exit 105
fi

# test days input for valid number
if ! [[ $MAX_DAYS_DEFAULT =~ ^[0-9]+$ ]]; then
    # not a valid number or negative
    echo "${DATELOG} ${LOG_ID} Not a valid positve integer for -d option." >> ${LOG}
    echo "${DATELOG} ${LOG_ID} The -d option is incorrect. Exit code: 10" >> ${LOG}
    exit 10
fi

# Checking lock file
test -r "${LOCK_FILE}"
if [ $? -eq 0 ];then
    echo "${DATELOG} ${LOG_ID} There is another mega delete old process running! Exit Code: 100" >> ${LOG}
    exit 100
fi

touch "${LOCK_FILE}" 2> /dev/null

# Loops will not pick up incremental count so will need to utilize tmp files
# see: https://stackoverflow.com/questions/10515964/counter-increment-in-bash-loop-not-working?utm_medium=organic&utm_source=google_rich_qa&utm_campaign=google_rich_qa
TMP_FILE_COUNT=$(mktemp)
TMP_FILE_COUNT_DELETED=$(mktemp)
# set the initial value of 0 in the temp files for counting
echo 0 >> ${TMP_FILE_COUNT}
echo 0 >> ${TMP_FILE_COUNT_DELETED}

if [ -z "${MEGA_SERVER_PATH}" ]; then
    # No argument for user supplied for folder
    CURRENT_MEGA_FOLDER="${MEGA_DEFAULT_ROOT}"
    IN_ROOT=1
else
    CURRENT_MEGA_FOLDER="${MEGA_DEFAULT_ROOT}${MEGA_SERVER_PATH}"
fi
# calc how what date to use as the max age for expired files.
MAX_AGE=$(date --date="-${MAX_DAYS_DEFAULT} day" +%s)

if [[ -n "${CURRENT_CONFIG}" ]]; then
    # Argument is given for default configuration for that contains user account and password
    test -r "${CURRENT_CONFIG}"
    if [[ $? -ne 0 ]]; then
        echo "${DATELOG} ${LOG_ID} Config file '${CURRENT_CONFIG}' does not exist or can not gain read access." >> ${LOG}
        exit 111
    fi
    HAS_CONFIG=1
fi

if [[ $HAS_CONFIG -eq 0 ]]; then
    # No argument is given for default configuration for that contains user account and password
    MEGA_FILES=$(${MT_MEGA_LS} -l "$CURRENT_MEGA_FOLDER")
else
    # Argument is given for default configuration that contains user account and password
    MEGA_FILES=$(${MT_MEGA_LS} --config "$CURRENT_CONFIG" -l "$CURRENT_MEGA_FOLDER")
fi

FROM_DATESTAMP=$(date -d "@$MAX_AGE")
echo "${DATELOG} ${LOG_ID} Processing Files older than '${FROM_DATESTAMP}' for folder '${CURRENT_MEGA_FOLDER}' " >> ${LOG}

echo "${MEGA_FILES}" | while read line
do

    FILE_TYPE=$(echo "$line" | awk '{print $3}')
    if [[ $FILE_TYPE = "-" ]]; then
        # this is root folder, continue
        continue
    fi
    # when FILE_TYPE = 0 it is a file
    # when FILE_TYPE = 1 it is a folder
    # when FILE_TYPE = 2 it is root
    if [[ ${FILE_TYPE} -eq 0 ]]; then
        FILE_COUNT=$(($(cat $TMP_FILE_COUNT) + 1))
        # clear the tmp file
        truncate -s 0 "${TMP_FILE_COUNT}"
        # Store the new value
        echo $FILE_COUNT >> ${TMP_FILE_COUNT}
        # The file modifed date is in column 5
        FILE_STR_DATE=$(echo "$line" | awk '{print $5}')

        # Convert the file date into system date
        FILE_DATE=$(date -d ${FILE_STR_DATE} +%s)

        # compare the file system date to the Max age we want to keep
        if [ $MAX_AGE -ge $FILE_DATE ];
        then
            # use grep to get the complete file path form megals output
            FILE_PATH=$(echo "$line" | grep -o '/Root.*')
            
            if [[ $HAS_CONFIG -eq 0 ]]; then
                # No argument is given for default configuration for that contains user account and password
                ${MT_MEGA_RM} "${FILE_PATH}" >> ${LOG}
            else
                # Argument is given for default configuration that contains user account and password
                ${MT_MEGA_RM} --config "${CURRENT_CONFIG}" "${FILE_PATH}" >> ${LOG}
            fi
            echo "${DATELOG} ${LOG_ID} Deleted '${FILE_PATH}' with modifed date of: ${FILE_STR_DATE}" >> ${LOG}

            # FILE_COUNT_DELETED=$(($FILE_COUNT_DELETED +1))
            FILE_COUNT_DELETED=$(($(cat ${TMP_FILE_COUNT_DELETED}) + 1))
            # clear the tmp file
            truncate -s 0 "${TMP_FILE_COUNT_DELETED}"
            # Store the new value
            echo $FILE_COUNT_DELETED >> ${TMP_FILE_COUNT_DELETED}
        fi  
    fi
done

FILE_COUNT=$(cat ${TMP_FILE_COUNT})
FILE_COUNT_DELETED=$(cat ${TMP_FILE_COUNT_DELETED})
unlink ${TMP_FILE_COUNT}
unlink ${TMP_FILE_COUNT_DELETED}
echo "${DATELOG} ${LOG_ID} Total Files: ${FILE_COUNT}" >> ${LOG}
echo "${DATELOG} ${LOG_ID} Deleted Files: ${FILE_COUNT_DELETED}" >> ${LOG}

if [ $HAS_CONFIG -eq 0 ]; then
    # No argument is given for default configuration for that contains user account and password
    # tr will remove the line breaks in this case and replace with a space to get the output on one line
    CURRENT_SPACE=$(${MT_MEGA_DF} --human | tr '\n' ' ')
else
    # Argument is given for default configuration that contains user account and password
    CURRENT_SPACE=$(${MT_MEGA_DF} --config "$CURRENT_CONFIG" --human | tr '\n' ' ')
fi
echo "${DATELOG} ${LOG_ID} ${CURRENT_SPACE}" >> ${LOG}
rm -f "${LOCK_FILE}"
exit 0