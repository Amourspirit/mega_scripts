#!/bin/bash
#
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
# Upload file to a folder for a mega.nz account.
# Created by Paul Moss
# Created: 2018-05-27
# File Name: mega_upload_file.sh
# Github: https://github.com/Amourspirit/mega_scripts
# Help: https://amourspirit.github.io/mega_scripts/mega_upload_fiilesh.html
#
# -p: Required: -p pass location to upload your file to Mega. This is the folder name on mega.nz where your upload will be sent.
#     Exclude the "/Root" for your path. If your location is "/Root/myserver/backups" then pass "/myserver/backups" as the first parameter
# -l: Required: -l pass in the file to upload to Mega. This must be the full path to the file that is to be uploaded to Mega.
# -i: Optional: -i pass in the configuration file that contains the account information for mega.nz. Defaults to ~/.megarc
# -o: Optional: -o pass in the log file to log output from this script in.
# -d: Optional: -d pass in the date of Log in the format of yyyy-mm-dd-hh-mm-ss. This will be used as the date stamp in the log file
#     Example: 2018-06-21-14-31-22
#     If -o is set to "s" this -d will be ignored.
# -v: Display the current version of this script
# -h: Display script help
#
# If this script is called from another script then having an option for log and log date makes it so the all entries in the log filee may have the same log date.
#
# Exit Codes
# Code  Defination
#   0   Normal Exit. No Errors Encountered.
#   3   No write privileges to create log file
#   4   Log file exist but no write privileges
# 100   There is another mega process running. Can not continue.
# 103   megaput not found. Megtools requires installing
# 104   No argument supplied for Mega Server Path
# 110   No mega server path specified
# 111   Optional argument Param 3 was passed in but the config can not be found or we do not have read permissions
# 112   The file to upload does not exist or can not gain read access.

# trims white space from input
MS_VERSION='1.3.2.0'
function trim () {
    local var=$1;
    var="${var#"${var%%[![:space:]]*}"}";   # remove leading whitespace characters
    var="${var%"${var##*[![:space:]]}"}";   # remove trailing whitespace characters
    echo -n "$var";
}
LOG='/var/log/mega_upload_file.log'
DATELOG=$(date +'%Y-%m-%d-%H-%M-%S')

# create an array that contains configuration values
# put values that need to be evaluated using eval in single quotes
typeset -A SCRIPT_CONF # init array
SCRIPT_CONF=( # set default values in config array
    [LOG_ID]='MEGA PUT:'
    [LOG]="${LOG}"
)
# It is not necessary to have .mega_scriptsrc for thi script
if [[ -f "${HOME}/.mega_scriptsrc" ]]; then
    # make tmp file to hold section of config.ini style section in
    TMP_CONFIG_FILE=$(mktemp)
    # SECTION_NAME is a var to hold which section of config you want to read
    SECTION_NAME="MEGA_UPLOAD_FILE"
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


LOG_ID=${SCRIPT_CONF[LOG_ID]}
LOG=${SCRIPT_CONF[LOG]}
MEGA_DEFAULT_ROOT="/Root"
FILE_TO_UPLOAD=''
LOCK_FILE="/tmp/mega_upload_file_lock"
CURRENT_MEGA_FOLDER=''
CURRENT_CONFIG=''
CURRENT_SPACE=''
MEGA_FULL_PATH=''
HAS_CONFIG=0

usage() { echo "$(basename $0) usage:" && grep "[[:space:]].)\ #" $0 | sed 's/#//' | sed -r 's/([a-z])\)/-\1/'; exit 0; }
[ $# -eq 0 ] && usage
while getopts ":hvp:l:i:o:d:" arg; do
  case $arg in
    p) # Required: Specify -p The path to upload on Mega.nz.
        MEGA_FULL_PATH="${OPTARG}"
        ;;
    l) # Required: Specify -l The path of the local file to upload onto Mega.nz.
        FILE_TO_UPLOAD="${OPTARG}"
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
    h | *) # -h Display help.
        echo 'For online help visit: https://amourspirit.github.io/mega_scripts/mega_upload_fiilesh.html'
        usage
        exit 0
        ;;
  esac
done

# the follow vars are eval in case they contain other expandable vars such as $HOME or ${USER}
LOG=$(eval echo ${LOG})
CURRENT_CONFIG=$(eval echo ${CURRENT_CONFIG})
FILE_TO_UPLOAD=$(eval echo ${FILE_TO_UPLOAD})

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
if [ -z "${MEGA_FULL_PATH}" ]; then
    # No argument for user supplied mega server path
    echo "${DATELOG} ${LOG_ID} No argument supplied Mega server path." >> ${LOG}
    exit 104
else
    MEGA_FULL_PATH="${MEGA_DEFAULT_ROOT}${MEGA_FULL_PATH}"
fi
if [ -z "${FILE_TO_UPLOAD}" ]; then
    # No argument the file to upload to upload
    echo "${DATELOG} ${LOG_ID} You are required pass in the file to upload to Mega." >> ${LOG}
    exit 110
fi
# Checking that the actual file to upload exist and have read premissions
test -r "${FILE_TO_UPLOAD}"
if [ $? -ne 0 ]; then
    echo "${DATELOG} ${LOG_ID} File to upload '${FILE_TO_UPLOAD}' does not exist or can not gain read access." >> ${LOG}
    exit 112
fi
if [[ -n "${CURRENT_CONFIG}" ]]; then
    # Argument is given for default configuration for that contains user account and password
    test -r "${CURRENT_CONFIG}"
    if [[ $? -ne 0 ]]; then
        echo "${DATELOG} ${LOG_ID} Config file '${CURRENT_CONFIG}' does not exist or can not gain read access." >> ${LOG}
        exit 111
    fi
    HAS_CONFIG=1
fi

# https://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
if ! [ -x "$(command -v megaput)" ]; then
    echo "${DATELOG} ${LOG_ID} You have not enabled MEGA put." >> ${LOG}
    echo "${DATELOG} ${LOG_ID} You need to install megatools from http://megatools.megous.com" >> ${LOG}
    echo "${DATELOG} ${LOG_ID} MEGA put failed" >> ${LOG}
    exit 103
fi

# Checking lock file
test -r "${LOCK_FILE}"
if [ $? -eq 0 ]; then
    echo "${DATELOG} ${LOG_ID} There is another mega put file process running." >> ${LOG}
    exit 100
fi
touch "${LOCK_FILE}" 2> /dev/null

echo "${DATELOG} ${LOG_ID} Uploading '${FILE_TO_UPLOAD}' to directory '${MEGA_FULL_PATH}' on MEGA.nz." >> ${LOG}

if [[ $HAS_CONFIG -eq 0 ]]; then
    # No argument is given for default configuration for that contains user account and password
    # remove escape char that is at the beginning by only printing printable chars | tr -dc '[[:print:]]'
    MEGAPUT_RESULT=$(megaput --path "${MEGA_FULL_PATH}" "${FILE_TO_UPLOAD}" | tr -dc '[[:print:]]')
    if [ ! -z "$MEGAPUT_RESULT" ]; then
        echo "${DATELOG} ${LOG_ID} Upload result: ${MEGAPUT_RESULT}" >> ${LOG}
    fi
else
    # Argument is given for default configuration that contains user account and password
    # remove escape char that is at the beginning by only printing printable chars | tr -dc '[[:print:]]'
    MEGAPUT_RESULT=$(megaput --config "${CURRENT_CONFIG}" --path "${MEGA_FULL_PATH}" "${FILE_TO_UPLOAD}" | tr -dc '[[:print:]]')
    if [ ! -z "$MEGAPUT_RESULT" ]; then
        echo "${DATELOG} ${LOG_ID} Upload result: ${MEGAPUT_RESULT}" >> ${LOG}
    fi
fi
echo "${DATELOG} ${LOG_ID} MEGA Upload Done" >> ${LOG}
rm -f "${LOCK_FILE}"
exit 0
