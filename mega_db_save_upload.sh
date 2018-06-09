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
# Script to backup database and upload to a mega.nz account
# Created by Paul Moss
# Created: 2018-05-27
# Version 1.2.2.0
# File Name: mega_db_save_upload.sh
# See Pastebin: https://pastebin.com/wiEGvQMc
#
# Assumptions:
#   Script assumes that you have enable .my.cnf and placed your MysqlDump username and password in the ~/.my.cnf file.
#   Scritp assumes that you have setup a mega.zn file and created a default ~/.megarc file with your email and password for the account.
#       Other mega config files can be created and passed in as a parameter to this script
#       config file such as ~/my.cnf and ~/.mgearc must be chmod 0700
#
# Required parameter 1: pass in the user for the current backup
# Required parameter 2: pass in the name of the database to be backed up to mega.nz
# Optional parameter 3: pass in the configuration file that contains the account information for mega.nz. Defaults to ~/.megarc
#
# General Notes:
#     If user is not passed in or user does not exist then log will be written to /var/log/${LOG_NAM}
#
# Examples:
#     /bin/bash /usr/local/bin/mega_db_save_upload.sh "user" "user_db"
#     /bin/bash /usr/local/bin/mega_db_save_upload.sh "user_fan" "user_fan_db" ~/.megarc_user_fan
#
# Exit Codes
#     0 Normal Exit script found no issues
#     20 No argument for user supplied for user
#     21 No argument for user supplied for database
#     30 File not found on mega.nz found
#     41 If megamkdir had error creating directory on mega.nz
#     42 If a file was found with the same name as part of the path on mega.nz
#     50 ~/.my.cnf for mysqldump is not found or script does not have read premissions.
#     51 ~/.megarc for mega.nz is not found or script does not have read premissions.
#     52 The database passed in to the script does not exist
#     53 The user passed in to the script does not exist
#     100 There is another mega process running
#     101 megarm not found. Megtools requires installing
#     102 megals not found. Megtools requires installing
#     103 megaput not found. Megtools requires installing
#     104 no argument supplied for Mega Server Path
#     110 no mega server path specified
#     111 Optional argument two was passed in but the config can not be foud or we do not have read permissions
#     112 The file to upload does not exist or can not gain read access.
#     115 megamkdir not found. Megtools requires installing

ENCRYPT_OUTPUT="yes"
MEGA_ENABLED="yes"
DELETE_BZ2_FILE="yes"
MEGA_DELETE_OLD_BACKUPS="yes"
MEGA_DELETE_LOCAL_FILE="yes"
# set SEND_EMAIL_ON_ERROR="yes" to send email on error. Also must have valid SEND_EMAIL_TO email address and SEND_EMAIL_FROM address
SEND_EMAIL_ON_ERROR="no"
# 'SEND_EMAIL_TO' FOR MULTIPLE ADDRESS SEPERATE BY , SPACE
# EXAMPLE: SEND_EMAIL_TO="myemail1@domain.com, myemail2@domain.com, myemail3@otherdomain.com"
SEND_EMAIL_TO=""
SEND_EMAIL_FROM="noreply@myserver.com"
SEND_MAIL_CLIENT="/usr/sbin/sendmail"
GPG_OWNER="bbserver"
SERVER_NAME="bbserver"
DB_USER="root"
LOG_NAME="mega_db.log"
LOG_ID="MEGA DATABASE: "
DATELOG=`date +'%Y-%m-%d-%H-%M-%S'`
LOG_SEP="=========================================${DATELOG}========================================="
SYS_LOG_DIR="/var/log"
SYS_LOG="$SYS_LOG_DIR/$LOG_NAME"
THIS_SCRIPT=`basename "$0"`

# if log is not supplied then redirect to stdout
if [[ -z $SYS_LOG ]]; then
  SYS_LOG=/dev/stdout
fi

if [ -z "$1" ]
  then
    echo "${LOG_SEP}" >> ${SYS_LOG}
    echo "${DATELOG} ${LOG_ID}No argument for user supplied for user! Exiting! Exit Code 20" >> ${SYS_LOG}
    echo "${LOG_SEP}" >> ${SYS_LOG}
    echo "" >> ${SYS_LOG}
    if [[ $SEND_EMAIL_ON_ERROR = "yes" && -n SEND_EMAIL_TO ]]; then
        EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 4 $SYS_LOG_DIR/${LOG_NAME}) \n\n Log File: '${SYS_LOG}'")
        ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
    fi
    exit 20
fi
USER="$1"

USER_ID=$(id -u "${USER}" &>/dev/null)
# $? is 0 if found and 1 if not found for id -u user
if [ $? -ne 0 ]; then
    echo "${LOG_SEP}" >> ${SYS_LOG}
    echo "${DATELOG} ${LOG_ID}'${USER}' does Not Exit. Unable to continue: Exit Code: 53" >> ${SYS_LOG}
    echo "${LOG_SEP}" >> ${SYS_LOG}
    echo "" >> ${SYS_LOG}

    if [[ $SEND_EMAIL_ON_ERROR = "yes" && -n SEND_EMAIL_TO ]]; then
        EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 4 $SYS_LOG_DIR/${LOG_NAME}) \n\n Log File: '${SYS_LOG}'")
        ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
    fi
    exit 53
fi
# done with USER_ID
unset USER_ID

LOG="/home/${USER}/logs/${LOG_NAME}"

# if log is not supplied then redirect to stdout
if [[ -z $LOG ]]; then
  LOG=/dev/stdout
fi

echo "${LOG_SEP}" >> ${LOG}

if [ -z "$2" ]
  then
    echo "${LOG_SEP}" >> ${LOG}
    echo "No argument for user supplied for database! Exiting" >> ${LOG}
    echo "${DATELOG} ${LOG_ID}No argument for user supplied for database! Exit Code: 21" >> ${LOG}
    echo "${LOG_SEP}" >> ${LOG}
    echo "" >> ${LOG}
    if [[ $SEND_EMAIL_ON_ERROR = "yes" && -n SEND_EMAIL_TO ]]; then
        EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 5 ${LOG}) \n\n Log File: '${LOG}'")
        ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
    fi
    exit 21
fi

BAK_DIR="/home/${USER}/tmp"
DB_NAME="$2"
DB_NAME_NEW=$DATELOG"_$DB_NAME"
DB_FILE_SQL=$BAK_DIR/$DB_NAME_NEW".sql"
DB_FILE=$DB_FILE_SQL".bz2"


SYS_LOG="/var/log/mega_db.log"
MSD="/usr/bin/mysqldump"
LOCK_FILE="/tmp/mega_backup_db_lock"
MEGA_DEL_OLD_NAME="mega_del_old.sh"
MEGA_UPLOAD_FILE_NAME="mega_upload_file.sh"
MEGA_EXIST_FILE_NAME="mega_dir_file_exist.sh"
MEGA_MKDIR_FILE_NAME="mega_mkdir.sh"
SCRIPT_DIR=$(dirname "$0")
MEGA_BACKUP_DIR="/$SERVER_NAME/backups/${USER}/database"
MEGA_DEL_OLD_SCRIPT=$SCRIPT_DIR"/"$MEGA_DEL_OLD_NAME
MEGA_UPLOAD_FILE_SCRIPT=$SCRIPT_DIR"/"$MEGA_UPLOAD_FILE_NAME
MEGA_EXIST_FILE_SCRIPT=$SCRIPT_DIR"/"$MEGA_EXIST_FILE_NAME
MEGA_MKDIR_FILE_SCRIPT=$SCRIPT_DIR"/"$MEGA_MKDIR_FILE_NAME
DAYS_TO_KEEP_BACKUP=60
BASH="/bin/bash"
MYSQL_DIR="/var/lib/mysql"
CURRENT_CONFIG=""
HAS_CONFIG=0
OUTPUT_FILE=$DB_FILE
if [[ $ENCRYPT_OUTPUT = "yes" ]]; then
    OUTPUT_FILE=$OUTPUT_FILE".gpg"
fi

OUTPUT_FILE_NAME=$(basename ${OUTPUT_FILE})

if [[ -n "$3" ]]; then
    # Argument is given for default configuration for that contains user account and password
    CURRENT_CONFIG="$3"
    test -r "${CURRENT_CONFIG}"
    if [ $? -ne 0 ]; then
        echo "${LOG_SEP}" >> ${LOG}
        echo "${DATELOG} ${LOG_ID}Config file '${CURRENT_CONFIG}' does not exist or can not gain read access! Exit Code: 111" >> ${LOG}
        echo "${LOG_SEP}" >> ${LOG}
        echo "" >> ${LOG}
        if [[ $SEND_EMAIL_ON_ERROR = "yes" && -n SEND_EMAIL_TO ]]; then
            EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 4 ${LOG}) \n\n Log File: '${LOG}'")
            ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
        fi
        exit 111
    fi
fi
if [ ! -z "$CURRENT_CONFIG" ]; then
  HAS_CONFIG=1
fi

# test to see if MySql database exist as a folder database if not assume database does not exit
# https://stackoverflow.com/questions/7364709/bash-script-check-if-mysql-database-exists-perform-action-based-on-result#7364807
test -d "$MYSQL_DIR/$DB_NAME"
if [ $? -ne 0 ]; then
    echo "${DATELOG} ${LOG_ID}'$DB_NAME' does Not Exit. Unable to continue: Exit Code: 52" >> ${LOG}
    echo "${LOG_SEP}" >> ${LOG}
    echo "" >> ${LOG}
    if [[ $SEND_EMAIL_ON_ERROR = "yes" && -n SEND_EMAIL_TO ]]; then
        EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 4 ${LOG}) \n\n Log File: '${LOG}'")
        ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
    fi
    exit 52
fi

test -r ~/.my.cnf
if [ $? -ne 0 ]; then
    echo "${DATELOG} ${LOG_ID}~/.my.cnf must be set up for MysqlDump to do its job. Unable to continue: Exit Code: 50" >> ${LOG}
    echo "${LOG_SEP}" >> ${LOG}
    echo "" >> ${LOG}
    if [[ $SEND_EMAIL_ON_ERROR = "yes" && -n SEND_EMAIL_TO ]]; then
        EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 4 ${LOG}) \n\n Log File: '${LOG}'")
        ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
    fi
    exit 50
fi

if [[ $MEGA_ENABLED = "yes" && $HAS_CONFIG -eq 0 ]]; then
    # no config has been passed into script. check and see if the default exist
    test -r ~/.megarc
    if [ $? -ne 0 ];then
        echo "${DATELOG} ${LOG_ID}~/.megarc must be set up and readable by current to upload to mega when parameter 3 is omitted. Unable to continue: Exit Code: 51" >> ${LOG}
        echo "${LOG_SEP}" >> ${LOG}
        echo "" >> ${LOG}
        if [[ $SEND_EMAIL_ON_ERROR = "yes" && -n SEND_EMAIL_TO ]]; then
            EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 4 ${LOG}) \n\n Log File: '${LOG}'")
            ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
        fi
        exit 51
    fi
fi
# make the backup directory if it does not exist
mkdir -p "$BAK_DIR"
# Checking lock file
test -r "${LOCK_FILE}"
if [ $? -eq 0 ];then
    echo "${DATELOG} ${LOG_ID}There is another mega backup database process running! Exit Code: 100" >> ${LOG}
    echo "${LOG_SEP}" >> ${LOG}
    echo "" >> ${LOG}
    if [[ $SEND_EMAIL_ON_ERROR = "yes" && -n SEND_EMAIL_TO ]]; then
        EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 4 ${LOG}) \n\n Log File: '${LOG}'")
        ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
    fi
    exit 100
fi

cd ${BAK_DIR}

echo "${DATELOG} ${LOG_ID}Generating '${OUTPUT_FILE}' from database '${DB_NAME}'." >> ${LOG}
if [[ $ENCRYPT_OUTPUT = "yes" ]]; then
    ${MSD} -u ${DB_USER} -h localhost -a ${DB_NAME} | bzip2  > ${DB_FILE} && gpg --encrypt --recipient "$GPG_OWNER" ${DB_FILE}
    echo "${DATELOG} ${LOG_ID}'${DB_FILE}' has been encrypted using gpg as'${OUTPUT_FILE}'." >> ${LOG}
else
    ${MSD} -u ${DB_USER} -h localhost -a ${DB_NAME} | bzip2  > ${DB_FILE}
    echo "${DATELOG} ${LOG_ID}gpg encryption has been disabled in the script." >> ${LOG}
fi
echo "${DATELOG} ${LOG_ID}Generated '${OUTPUT_FILE}' from database '${DB_NAME}'." >> ${LOG}
if [[ $DELETE_BZ2_FILE = "yes" ]]; then
    rm -f ${DB_FILE}
    echo "${DATELOG} ${LOG_ID}Delete bz2 file is enabled and '${DB_FILE}' has been deleted from '${BAK_DIR}'." >> ${LOG}
else
    echo "${DATELOG} ${LOG_ID}Delete bz2 file is disabled and '${DB_FILE}' is still in '${BAK_DIR}'." >> ${LOG}
fi

# Create the path to upload to on mega if it does not exist
if [[ $MEGA_ENABLED = "yes" ]]; then
    echo "${DATELOG} ${LOG_ID}Checking mega.nz path to see if it '$MEGA_BACKUP_DIR' directory exist. Will created if not." >> ${LOG}
    if [[ $HAS_CONFIG -eq 0 ]]; then
        # No argument is given for default configuration for that contains user account and password
        ${BASH} "${MEGA_MKDIR_FILE_SCRIPT}" "$MEGA_BACKUP_DIR"
    else
        # Argument is given for default configuration that contains user account and password
        ${BASH} "${MEGA_MKDIR_FILE_SCRIPT}" "$MEGA_BACKUP_DIR" "$CURRENT_CONFIG"
    fi
    EXIT_CODE=$?
    if [[ $EXIT_CODE -ne 0 ]]; then
        # there was a problem running the script
        echo "${DATELOG} ${LOG_ID}There was an issue running script '$MEGA_MKDIR_FILE_NAME'! Exit Code: $EXIT_CODE" >> ${LOG}
        echo "${LOG_SEP}" >> ${LOG}
        rm -f "${LOCK_FILE}"
        if [[ $SEND_EMAIL_ON_ERROR = "yes" && ! -z SEND_EMAIL_TO ]]; then
            EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 4 ${LOG}) \n\n Log File: '${LOG}'")
            ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
        fi
        exit $EXIT_CODE
    fi
    if [[ $MEGA_DELETE_OLD_BACKUPS = "yes" ]]; then
         # Remove any expired database backup files
        if [[ $HAS_CONFIG -eq 0 ]]; then
            # No argument is given for default configuration for that contains user account and password
            ${BASH} "${MEGA_DEL_OLD_SCRIPT}" "$MEGA_BACKUP_DIR" "$DAYS_TO_KEEP_BACKUP" "" "$LOG" "$DATELOG"
        else
            # Argument is given for default configuration that contains user account and password
            ${BASH} "${MEGA_DEL_OLD_SCRIPT}" "$MEGA_BACKUP_DIR" "$DAYS_TO_KEEP_BACKUP" "$CURRENT_CONFIG" "$LOG" "$DATELOG"
        fi
        EXIT_CODE=$?
        if [[ $EXIT_CODE -ne 0 ]]; then
            # there was a problem running the script
            echo "${DATELOG} ${LOG_ID}There was an issue running script '$MEGA_DEL_OLD_NAME'! Exit Code: $EXIT_CODE" >> ${LOG}
            echo "${LOG_SEP}" >> ${LOG}
            rm -f "${LOCK_FILE}"
            if [[ $SEND_EMAIL_ON_ERROR = "yes" && ! -z SEND_EMAIL_TO ]]; then
                EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 3 ${LOG}) \n\n Log File: '${LOG}'")
                ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
            fi
            exit $EXIT_CODE
        fi
    fi
    # Send new backup to mega.nz
    if [[ $HAS_CONFIG -eq 0 ]]; then
        # No argument is given for default configuration for that contains user account and password
        ${BASH} "${MEGA_UPLOAD_FILE_SCRIPT}" "${MEGA_BACKUP_DIR}" "${OUTPUT_FILE}" "" "$LOG" "$DATELOG"
    else
        # Argument is given for default configuration that contains user account and password
        ${BASH} "${MEGA_UPLOAD_FILE_SCRIPT}" "${MEGA_BACKUP_DIR}" "${OUTPUT_FILE}" "$CURRENT_CONFIG" "$LOG" "$DATELOG"
    fi
    EXIT_CODE=$?
    if [[ $EXIT_CODE -ne 0 ]]; then
        # there was a problem running the script
        echo "${DATELOG} ${LOG_ID}There was an issue running script '$MEGA_UPLOAD_FILE_NAME': Exit Code: $EXIT_CODE" >> ${LOG}
        echo "${LOG_SEP}" >> ${LOG}
        rm -f "${LOCK_FILE}"
        if [[ $SEND_EMAIL_ON_ERROR = "yes" && ! -z SEND_EMAIL_TO ]]; then
            EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 3 ${LOG}) \n\n Log File: '${LOG}'")
            ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
        fi
        exit $EXIT_CODE
    fi
    #confirm new file is on mega.nz
    echo "${DATELOG} ${LOG_ID}Checking mega.nz to see if backup has made it." >> ${LOG}
    if [[ -z "$CURRENT_CONFIG" ]]; then
        # No argument is given for default configuration for that contains user account and password
        ${BASH} "${MEGA_EXIST_FILE_SCRIPT}" "${MEGA_BACKUP_DIR}/${OUTPUT_FILE_NAME}"
    else
        # Argument is given for default configuration that contains user account and password
        ${BASH} "${MEGA_EXIST_FILE_SCRIPT}" "${MEGA_BACKUP_DIR}/${OUTPUT_FILE_NAME}" "$CURRENT_CONFIG"
    fi
    EXIT_CODE=$?
    if [[ $EXIT_CODE -ne 3 ]]; then
        # code 3 for this script means it found file.
        # there was a problem running the script
        echo "${DATELOG} ${LOG_ID}There was an issue running script '$MEGA_EXIST_FILE_NAME'. Script exited with code '$EXIT_CODE'! Exit Code: 30" >> ${LOG}
        echo "${LOG_SEP}" >> ${LOG}
        rm -f "${LOCK_FILE}"
        if [[ $SEND_EMAIL_ON_ERROR = "yes" && -n SEND_EMAIL_TO ]]; then
            EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 3 ${LOG}) \n\n Log File: '${LOG}'")
            ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
        fi
        exit 30
    else
        echo "${DATELOG} ${LOG_ID}File ${OUTPUT_FILE_NAME} has made it onto mega.nz" >> ${LOG}
    fi
    if [[ $MEGA_DELETE_LOCAL_FILE="yes" ]]; then
        #delete local file
        rm -f "${OUTPUT_FILE}"
        echo "${DATELOG} ${LOG_ID}Local file ${OUTPUT_FILE_NAME} has been deleted." >> ${LOG}
    fi
    # log the current space on mega.nz account
    if [[ $HAS_CONFIG -eq 0 ]]; then
        # No argument is given for default configuration for that contains user account and password
        # tr will remove the line breaks in this case and replace with a space to get the output on one line
        CURRENT_SPACE=$(megadf --human | tr '\n' ' ')
    else
        # Argument is given for default configuration that contains user account and password
        CURRENT_SPACE=$(megadf --config "$CURRENT_CONFIG" --human | tr '\n' ' ')
    fi
    echo "${DATELOG} ${LOG_ID}${CURRENT_SPACE}" >> ${LOG}
else
    echo "${DATELOG} ${LOG_ID}Mega is currently disabled in scritp" >> ${LOG}
fi

# Finish up
echo "${DATELOG} ${LOG_ID}Normal Exit! Exit Code: 0" >> ${LOG}
echo "${LOG_SEP}" >> ${LOG}
echo "" >> ${LOG}
# Clean up and exit
rm -f "${LOCK_FILE}"
exit 0
