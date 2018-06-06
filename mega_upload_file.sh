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
# Version 1.2.1.0
# File Name: mega_upload_file.sh
#
# Required parameter 1: pass location to upload your file to Mega. This is the folder name on mega.nz where your upload will be sent.
#     Exclude the "/Root" for your path. If your location is "/Root/myserver/backups" then pass "/myserver/backups" as the first parameter
# Required parameter 2: pass in the file to upload to Mega. This must be the full path to the file that is to be uploaded to Mega.
# Optional parameter 3: pass in the configuration file that contains the account information for mega.nz. Defaults to ~/.megarc
# Optional parameter 4: pass in the log file to log output from this script in.
# Optional parameter 5: pass in the log file date in the format of yyyy-mm-dd-H-M-S (2018-05-27-01-34-06)
#
# If this script is called from another script then having an option for log and log date makes it so the all entries in the log filee may have the same log date.
#
# Exit Codes
#     0 No know issues. script exited normally
#     100 There is another mega upload process running
#     103 megaput not found. Megtools requires installing
#     104 no argument supplied for Mega Server Path
#     110 no mega server path specified
#     111 Argument for config was passed in but the config file can not be found or we do not have read permissions
#     112 The file to upload does not exist or can not gain read access.

MEGA_DEFAULT_ROOT="/Root"
DATELOG=`date +'%Y-%m-%d-%H-%M-%S'`
LOG_ID="MEGA PUT: "
LOG="/var/log/mega_upload_file.log"
FILE_TO_UPLOAD=""
LOCK_FILE="/tmp/mega_upload_file_lock"
CURRENT_MEGA_FOLDER=""
CURRENT_CONFIG=""
CURRENT_SPACE=""
MEGA_FULL_PATH=""
HAS_CONFIG=0

if [[ -n "$4" ]]; then
    if [[ "$4" = "none" ]]; then
        LOG=""
    elif [[ "$4" = "silent" ]]; then
        LOG=2>/dev/null
    else
        LOG="$4"
    fi
fi

# if log is not supplied then redirect to stdout
if [[ -z $LOG ]]; then
  LOG=/dev/stdout
fi

# https://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
if ! [ -x "$(command -v megaput)" ]; then
    echo "${DATELOG} ${LOG_ID}You have not enabled MEGA put." >> ${LOG}
    echo "${DATELOG} ${LOG_ID}You need to install megatools from http://megatools.megous.com" >> ${LOG}
    echo "${DATELOG} ${LOG_ID}MEGA put failed" >> ${LOG}
    exit 103
fi
if [ -z "$1" ]; then
    # No argument for user supplied mega server path
    echo "${DATELOG} ${LOG_ID}No argument supplied Mega server path." >> ${LOG}
    exit 104
else
    MEGA_FULL_PATH="$MEGA_DEFAULT_ROOT$1"
fi
if [ -z "$2" ]; then
    # No argument the file to upload to upload
    echo "${DATELOG} ${LOG_ID}You are required pass in the file to upload to Mega." >> ${LOG}
    exit 110
else
    FILE_TO_UPLOAD="$2"
fi

if [[ -n "$3" ]]
then
    # Argument is given for default configuration for that contains user account and password
    CURRENT_CONFIG="$3"
    test -r "${CURRENT_CONFIG}"
    if [ $? -ne 0 ]; then
        echo "${DATELOG} ${LOG_ID}Config file '${CURRENT_CONFIG}' does not exist or can not gain read access." >> ${LOG}
        exit 111
    fi
fi

if [ -n "$CURRENT_CONFIG" ]; then
  HAS_CONFIG=1
fi


if [[ -n "$5" ]]
then
    # Argument is given for date log
    DATELOG="$5"
fi

# Checking that the actual file to upload exist and have read premissions
test -r "${FILE_TO_UPLOAD}"
if [ $? -ne 0 ]; then
    echo "${DATELOG} ${LOG_ID}File to upload '${FILE_TO_UPLOAD}' does not exist or can not gain read access." >> ${LOG}
    exit 112
fi

# Checking lock file
test -r "${LOCK_FILE}"
if [ $? -eq 0 ]; then
    echo "${DATELOG} ${LOG_ID}There is another mega put file process running." >> ${LOG}
    exit 100
fi
touch "${LOCK_FILE}" 2> /dev/null

echo "${DATELOG} ${LOG_ID}Uploading '${FILE_TO_UPLOAD}' to directory '${MEGA_FULL_PATH}' on MEGA.nz." >> ${LOG}

if [[ $HAS_CONFIG -eq 0 ]]; then
    # No argument is given for default configuration for that contains user account and password
    # remove escape char that is at the beginning by only printing printable chars | tr -dc '[[:print:]]'
    MEGAPUT_RESULT=$(megaput --path "${MEGA_FULL_PATH}" "${FILE_TO_UPLOAD}" | tr -dc '[[:print:]]')
    if [ ! -z "$MEGAPUT_RESULT" ]; then
        echo "${DATELOG} ${LOG_ID}Upload result: ${MEGAPUT_RESULT}" >> ${LOG}
    fi
else
    # Argument is given for default configuration that contains user account and password
    # remove escape char that is at the beginning by only printing printable chars | tr -dc '[[:print:]]'
    MEGAPUT_RESULT=$(megaput --config "${CURRENT_CONFIG}" --path "${MEGA_FULL_PATH}" "${FILE_TO_UPLOAD}" | tr -dc '[[:print:]]')
    if [ ! -z "$MEGAPUT_RESULT" ]; then
        echo "${DATELOG} ${LOG_ID}Upload result: ${MEGAPUT_RESULT}" >> ${LOG}
    fi
fi
echo "${DATELOG} ${LOG_ID}MEGA Upload Done" >> ${LOG}
rm -f "${LOCK_FILE}"
exit 0
