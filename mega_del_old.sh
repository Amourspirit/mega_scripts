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
# Version 1.2.1.0
# File Name: mega_del_old.sh
#
# Optional parameter 1: pass in the folder to delete older files from
# Optional parameter 2: pass in the number of days as an integer from todays date to delete files older then
# Optional parameter 3: pass in the configuration file that contains the account information for mega.nz. Defaults to ~/.megarc
# Optional parameter 4: pass in the log file to log output from this script in.
# Optional parameter 5: pass in the log file date in the format of yyyy-mm-dd-H-M-S (2018-05-27-01-34-06)
#
# If this script is called from another script then having an option for log and log date makes it so the entries all have the same log date.
#
# Exit Codes
#     0 Normal Exit
#     20 No argument for user supplied for user
#     21 No argument for user supplied for database
#     100 There is another mega delete old process running
#     101 megarm not found. Megtools requires installing
#     102 megals not found. Megtools requires installing
#     111 Optional argument two was passed in but the config can not be foud or we do not have read permissions

#  read the folder into a var
MEGA_DEFAULT_ROOT="/Root"
MAX_DAYS_DEFAULT="60"
DATELOG=`date +'%Y-%m-%d-%H-%M-%S'`
LOG_ID="MEGA DELETE OLD: "
LOG="/var/log/mega_delete_old.log"

FILE_COUNT=0
FILE_COUNT_DELETED=0
LOCK_FILE="/tmp/mega_del_old_lock"
CURRENT_MEGA_FOLDER=""
CURRENT_CONFIG=""
CURRENT_SPACE=""
MAX_AGE=""
MEGA_FILES=""
IN_ROOT=0

# https://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
if ! [ -x /usr/bin/megarm ]; then
    echo "${DATELOG} ${LOG_ID}You have not enabled MEGA remove." >> ${LOG}
    echo "${DATELOG} ${LOG_ID}You need to install megatools from http://megatools.megous.com! Exit Code: 101" >> ${LOG}
    echo "${DATELOG} ${LOG_ID}MEGA remove failed" >> ${LOG}
    exit 101
fi
if ! [ -x /usr/bin/megals ]; then
    echo "${DATELOG} ${LOG_ID}You have not enabled MEGA list." >> ${LOG}
    echo "${DATELOG} ${LOG_ID}You need to install megatools from http://megatools.megous.com! Exit Code: 102" >> ${LOG}
    echo "${DATELOG} ${LOG_ID}MEGA list failed" >> ${LOG}
    exit 102
fi

# Checking lock file
test -r "${LOCK_FILE}"
if [ $? -eq 0 ];then
    echo -e "${DATELOG} ${LOG_ID}There is another mega delete old process running! Exit Code: 100" >> ${LOG}
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

if [ -z "$1" ]; then
    # No argument for user supplied for folder
    CURRENT_MEGA_FOLDER="$MEGA_DEFAULT_ROOT"
    IN_ROOT=1
else
    CURRENT_MEGA_FOLDER="$MEGA_DEFAULT_ROOT$1"
fi

if [ -z "$2" ]; then
    # No argument for how old a file must be before it is deleted
    MAX_AGE=$(date --date="-$MAX_DAYS_DEFAULT day" +%s)
else
    MAX_AGE=$(date --date="-$2 day" +%s)
fi

if [[ ! -z "$3" ]]; then
    # Argument is given for default configuration for that contains user account and password
    CURRENT_CONFIG="$3"
    test -r "${CURRENT_CONFIG}"
    if [ $? -ne 0 ]; then
        echo "${DATELOG} ${LOG_ID}Config file '${CURRENT_CONFIG}' does not exist or can not gain read access! Exit Code: 111" >> ${LOG}
        exit 111
    fi
fi

if [[ ! -z "$4" ]]; then
    # Argument is given for log file
    LOG="$4"
fi

if [[ ! -z "$5" ]]; then
    # Argument is given for date log
    DATELOG="$5"
fi

if [[ -z "$CURRENT_CONFIG" ]]; then
    # No argument is given for default configuration for that contains user account and password
    MEGA_FILES=$(megals -l "$CURRENT_MEGA_FOLDER")
else
    # Argument is given for default configuration that contains user account and password
    MEGA_FILES=$(megals --config "$CURRENT_CONFIG" -l "$CURRENT_MEGA_FOLDER")
fi

FROM_DATESTAMP=$(date -d "@$MAX_AGE")
echo "${DATELOG} ${LOG_ID}Processing Files older than '${FROM_DATESTAMP}' for folder '${CURRENT_MEGA_FOLDER}' " >> ${LOG}

echo "$MEGA_FILES" | while read line
do

    # using awk NF (number of fields) to count from right to left to get field data.
    # using NF because not all lines suchs a root have the same number of columns before type
    # however the data we need to access is always the same form right ot left
    FILE_TYPE=$(echo "$line" | awk '{print $(NF-4)}')

    # when FILE_TYPE = 0 it is a file
    # when FILE_TYPE = 1 it is a folder
    # when FILE_TYPE = 2 it is root
    if [[ ${FILE_TYPE} -eq 0 ]]; then
        # (( FILE_COUNT++ ))
        #FILE_COUNT=$(($FILE_COUNT +1))
        FILE_COUNT=$(($(cat $TMP_FILE_COUNT) + 1))
        # clear the tmp file
        truncate -s 0 "${TMP_FILE_COUNT}"
        # Store the new value
        echo $FILE_COUNT >> ${TMP_FILE_COUNT}
        # The file modifed date is in column 5
        FILE_STR_DATE=$(echo "$line" | awk '{print  $(NF-2)}')

        # Convert the file date into system date
        FILE_DATE=$(date -d ${FILE_STR_DATE} +%s)

        # compare the file system date to the Max age we want to keep
        if [ $MAX_AGE -ge $FILE_DATE ];
        then
            # the full file name is in column 7
            FILE_PATH=$(echo "$line" | awk '{print  $(NF)}')
            
            if [[ -z "$CURRENT_CONFIG" ]]; then
                # No argument is given for default configuration for that contains user account and password
                megarm "$FILE_PATH" >> ${LOG}
            else
                # Argument is given for default configuration that contains user account and password
                megarm --config "$CURRENT_CONFIG" "$FILE_PATH" >> ${LOG}
            fi
            echo "${DATELOG} ${LOG_ID}Deleted '${FILE_PATH}' with modifed date of: ${FILE_STR_DATE}" >> ${LOG}

            # FILE_COUNT_DELETED=$(($FILE_COUNT_DELETED +1))
            FILE_COUNT_DELETED=$(($(cat $TMP_FILE_COUNT_DELETED) + 1))
            # clear the tmp file
            truncate -s 0 "${TMP_FILE_COUNT_DELETED}"
            # Store the new value
            echo $FILE_COUNT_DELETED >> ${TMP_FILE_COUNT_DELETED}
        fi  
    fi
done
FILE_COUNT=$(cat $TMP_FILE_COUNT)
FILE_COUNT_DELETED=$(cat $TMP_FILE_COUNT_DELETED)
unlink $TMP_FILE_COUNT
unlink $TMP_FILE_COUNT_DELETED
echo "${DATELOG} ${LOG_ID}Total Files: ${FILE_COUNT}" >> ${LOG}
echo "${DATELOG} ${LOG_ID}Deleted Files: ${FILE_COUNT_DELETED}" >> ${LOG}

if [ -z "$CURRENT_CONFIG" ]; then
    # No argument is given for default configuration for that contains user account and password
    # tr will remove the line breaks in this case and replace with a space to get the output on one line
    CURRENT_SPACE=$(megadf --human | tr '\n' ' ')
else
    # Argument is given for default configuration that contains user account and password
    CURRENT_SPACE=$(megadf --config "$CURRENT_CONFIG" --human | tr '\n' ' ')
fi
echo "${DATELOG} ${LOG_ID}${CURRENT_SPACE}" >> ${LOG}
rm -f "${LOCK_FILE}"
exit 0