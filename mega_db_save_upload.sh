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
# File Name: mega_db_save_upload.sh
# Github: https://github.com/Amourspirit/mega_scripts
# Help: https://amourspirit.github.io/mega_scripts/mega_db_save_uploadsh.html
#
# Assumptions:
#   Script assumes that you have enable .my.cnf and placed your MysqlDump username and password in the ~/.my.cnf file.
#   Scritp assumes that you have setup a mega.zn file and created a default ~/.megarc file with your email and password for the account.
#       Other mega config files can be created and passed in as a parameter to this script
#       config file such as ~/my.cnf and ~/.mgearc must be chmod 0700
#
# -u: Required: -u pass in the user for the current backup
# -d: Required: -d pass in the name of the database to be backed up to mega.nz
# -a: Optional: -a pass in the number of days as a positive integer before todays date to delete files older then from Mega.nz. Default is 60 days.
# -i: Optional: -i pass in the configuration file that contains the account information for mega.nz. Defaults to ~/.megarc
# -g: Optional: -g the gpg owner of the public key to use for encryption. If encryption is set to true and -g option is not set then .mega_scriptsrc must have the value set for GPG_OWNER
# -o: Optional: -o pass in the Log file to log to results
#     Can be value of "n" in which case results are outputed to the terminal window
#     Can be value of "s" in which case no results are written to a log file or terminal window.
#     Defaults to /home/${USER}/logs/mega_db.log
# -s: Optional: -s pass in the Log file to log User related errors
#     Can be value of "n" in which case results are outputed to the terminal window
#     Can be value of "s" in which case no results are written to a log file or terminal window.
#     Defaults to /var/log/mega_db.log (requires script be run as root)
# -f: Optional: -f to pass in options to forget or ignore checking for
#     c skips testing for mysql configuration
#     d skips testing for mysql database
#     u skips testing for unix user. Must override LOG, BAK_DIR and MEGA_BACKUP_DIR in .mega_scriptsrc
#     g skips testing if gpg public key exist
#     Example: -f 'dc' would skip checking of mysql configuration and database.
# -m: Optional: -m pass in the option for email on error. y for send on error and n for no send email on error. .mega_scriptsrc must be configured for email to send.
# -n: Optional: -n the name of the server used in logs both locally and in path name on mega.nz. If this flag is not set then SERVER_NAME must be set in .mega_scriptsrc
# -v: Display the current version of this script
# -h: Display script help
#
# General Notes:
#     If user is not passed in or user does not exist then log will be written to /var/log/mega_db.log my default. Can be overriden in .mega_scriptsrc
#
# Examples:
#     /bin/bash /usr/local/bin/mega_db_save_upload.sh -u 'user' -d 'user_db'
#     /bin/bash /usr/local/bin/mega_db_save_upload.sh -u 'user_fan' -d 'user_fan_db' -i "$HOME/.megarc_user_fan"
#
# Exit Codes
# Code    Definition
#   0     Normal Exit script found no issues
#   3     No write privileges to create log file
#   4     Log file exist but no write privileges
#  20     No argument for user supplied for user
#  21     No argument for user supplied for database
#  30     File not found on mega.nz
#  40     If no argument is give for parameter one, the path to check.
#  41     If megamkdir had error creating directory
#  42     If a file was found with the same name as part of the path
#  50     ~/.my.cnf for mysqldump is not found or script does not have read permissions.
#  51     ~/.megarc for mega.nz is not found or script does not have read permissions.
#  52     The database passed in to the script does not exist
#  53     The user passed in to the script does not exist
#  60     bzip2 not found
#  71     No read permissions for configuration file
#  72     It seems that no values have been set in the configuration file for section [MEGA_DB_SAVE_UPLOAD]
#  73     Invalid value in configuration
# 100     There is another mega process running. Can not continue.
# 101     megarm not found. Megtools requires installing
# 102     megals not found. Megtools requires installing
# 103     megaput not found. Megtools requires installing
# 104     No argument supplied for Mega Server Path
# 105     megadf not found. Megtools requires installing
# 110     No mega server path specified
# 111     Config can not be found or we do not have read permissions.
# 112     The file to upload does not exist or can not gain read access.
# 115     megamkdir not found. Megtools requires installing
# 116     Null value. Config file 'GPG_OWNER' of .mega_scriptrc or -g option must be set.
# 117     Config file 'GPG_OWNER' of .mega_scriptrc or -g option must be set and must be a valid GPG Public Key.
# 118     Unable to create directory to place backup file in.
# 119     Unable to write in directory for backup file.

MS_VERSION='1.3.2.0'
# function: trim
# Param 1: the variable to trim whitespace from
# Usage:
#   while read line; do
#       if [[ "$line" =~ ^[^#]*= ]]; then
#           setting_name=$(trim "${line%%=*}");
#           setting_value=$(trim "${line#*=}");
#           SCRIPT_CONF[$setting_name]=$setting_value
#       fi
#   done < "$TMP_CONFIG_COMMON_FILE"
function trim () {
    local var=$1;
    var="${var#"${var%%[![:space:]]*}"}";   # remove leading whitespace characters
    var="${var%"${var##*[![:space:]]}"}";   # remove trailing whitespace characters
    echo -n "$var";
}
# function: GpgPubKeyExist
# Param 1: name of public gpg key to search
# Usage:
#   GPG_OWNER='dlserver'
#   if GpgPubKeyExist "$GPG_OWNER"; then
#     echo "${GPG_OWNER} key exist"
#   else
#    echo "${GPG_OWNER} key not found"
#  fi
function GpgPubKeyExist () {
    local result='';
    result=$(gpg --list-public-keys | grep "^uid.*\s$1\s");
    if [[ -z $result ]]; then
        return 1
    fi
    return 0
}
THIS_SCRIPT=`basename "$0"`
CONFIG_FILE="$HOME/.mega_scriptsrc"
# it is not currently necessary to test for config file are there a no required settings from version 1.3.1.0
# test -e "${CONFIG_FILE}"
# if [ $? -ne 0 ];then
#     echo "Configuration '$HOME/.mega_scriptsrc' file has does not exist"
#     exit 70
# fi
#
# Check for a config file and if it exist then test to see if we can read it.
test -e "${CONFIG_FILE}"
if [ $? -eq 0 ];then
    test -r "${CONFIG_FILE}"
    if [[ $? -ne 0 ]];then
        echo "No read permissions for configuration '$HOME/.mega_scriptsrc'"
        exit 71
    fi
fi

DATELOG=$(date +'%Y-%m-%d-%H-%M-%S')

# create an array that contains configuration values
# put values that need to be evaluated using eval in single quotes
typeset -A SCRIPT_CONF # init array
SCRIPT_CONF=( # set default values in config array
    [ENCRYPT_OUTPUT]=true
    [MEGA_ENABLED]=true
    [DELETE_BZ2_FILE]=true
    [MEGA_DELETE_OLD_BACKUPS]=true
    [DAYS_TO_KEEP_BACKUP]=60
    [DELETE_LOCAL_BACKUP]=true
    [SEND_EMAIL_ON_ERROR]=false
    [SEND_EMAIL_TO]=''
    [SEND_EMAIL_FROM]=''
    [GPG_OWNER]=''
    [SERVER_NAME]=''
    [DB_USER]='root'
    [LOG]='/home/${USER}/logs/mega_db.log'
    [LOG_ID]='MEGA DATABASE:'
    [LOG_SEP]='=========================================${DATELOG}========================================='
    [MEGA_DEL_OLD_NAME]='mega_del_old.sh'
    [MEGA_UPLOAD_FILE_NAME]='mega_upload_file.sh'
    [MEGA_EXIST_FILE_NAME]='mega_dir_file_exist.sh'
    [MEGA_MKDIR_FILE_NAME]='mega_mkdir.sh'
    [MT_MEGA_DF]='megadf'
    [SYS_LOG]='/var/log/mega_db.log'
    [MYSQL_DIR]='/var/lib/mysql'
    [BAK_DIR]='/home/${USER}/tmp'
    [MEGA_BACKUP_DIR]='/${SERVER_NAME}/backups/${USER}/database'
    [MYSQL_TEST_DB]=true
    [MYSQL_TEST_CNF]=true
    [TEST_USER]=true
    [TEST_GPG]=true
)
# It is not necessary to have .mega_scriptsrc for thi script
if [[ -f "${HOME}/.mega_scriptsrc" ]]; then
    # make tmp file to hold section of config.ini style section in
    TMP_CONFIG_COMMON_FILE=$(mktemp)
    # SECTION_NAME is a var to hold which section of config you want to read
    SECTION_NAME="MEGA_COMMON"
    # sed in this case takes the value of SECTION_NAME and reads the setion from ~/config.ini
    sed -n '0,/'"$SECTION_NAME"'/d;/\[/,$d;/^$/d;p' "$HOME/.mega_scriptsrc" > $TMP_CONFIG_COMMON_FILE

    # test tmp file to to see if it is greater then 0 in size
    # MEGA_COMMON IS REQUIRED 
    # test -s "${TMP_CONFIG_COMMON_FILE}"
    # if [ $? -ne 0 ];then
    #     echo "It seems that no values have been set in the '$HOME/.mega_scriptsrc' for section [$SECTION_NAME]"
    #     unlink $TMP_CONFIG_COMMON_FILE
    #     exit 72
    # fi
    while read line; do
        if [[ "$line" =~ ^[^#]*= ]]; then
            setting_name=$(trim "${line%%=*}");
            setting_value=$(trim "${line#*=}");
            SCRIPT_CONF[$setting_name]=$setting_value
        fi
    done < "$TMP_CONFIG_COMMON_FILE"

    # release the tmp file that is contains the current section values
    unlink $TMP_CONFIG_COMMON_FILE


    # make tmp file to hold section of config.ini style section in
    TMP_CONFIG_FILE=$(mktemp)
    # SECTION_NAME is a var to hold which section of config you want to read
    SECTION_NAME="MEGA_DB_SAVE_UPLOAD"
    # sed in this case takes the value of SECTION_NAME and reads the setion from ~/config.ini
    sed -n '0,/'"$SECTION_NAME"'/d;/\[/,$d;/^$/d;p' "$HOME/.mega_scriptsrc" > $TMP_CONFIG_FILE

    # read the input of the tmp config file line by line
    # test tmp file to to see if it is greater then 0 in size
    # MEGA_DB_SAVE_UPLOAD section is not required as the defaults are fine
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

SERVER_NAME=${SCRIPT_CONF[SERVER_NAME]}
ENCRYPT_OUTPUT=${SCRIPT_CONF[ENCRYPT_OUTPUT]}
MEGA_ENABLED=${SCRIPT_CONF[MEGA_ENABLED]}
DELETE_BZ2_FILE=${SCRIPT_CONF[DELETE_BZ2_FILE]}
MEGA_DELETE_OLD_BACKUPS=${SCRIPT_CONF[MEGA_DELETE_OLD_BACKUPS]}
DAYS_TO_KEEP_BACKUP=${SCRIPT_CONF[DAYS_TO_KEEP_BACKUP]}
DELETE_LOCAL_BACKUP=${SCRIPT_CONF[DELETE_LOCAL_BACKUP]}
# set SEND_EMAIL_ON_ERROR="yes" to send email on error. Also must have valid SEND_EMAIL_TO email address and SEND_EMAIL_FROM address
SEND_EMAIL_ON_ERROR=${SCRIPT_CONF[SEND_EMAIL_ON_ERROR]}
# 'SEND_EMAIL_TO' FOR MULTIPLE ADDRESS SEPERATE BY , SPACE
# EXAMPLE: SEND_EMAIL_TO="myemail1@domain.com, myemail2@domain.com, myemail3@otherdomain.com"
SEND_EMAIL_TO=${SCRIPT_CONF[SEND_EMAIL_TO]}
SEND_EMAIL_FROM=${SCRIPT_CONF[SEND_EMAIL_FROM]}
GPG_OWNER=${SCRIPT_CONF[GPG_OWNER]}
DB_USER=${SCRIPT_CONF[DB_USER]}
LOG_ID=${SCRIPT_CONF[LOG_ID]}
LOG_SEP=${SCRIPT_CONF[LOG_SEP]}
MEGA_DEL_OLD_NAME=${SCRIPT_CONF[MEGA_DEL_OLD_NAME]}
MEGA_UPLOAD_FILE_NAME=${SCRIPT_CONF[MEGA_UPLOAD_FILE_NAME]}
MEGA_EXIST_FILE_NAME=${SCRIPT_CONF[MEGA_EXIST_FILE_NAME]}
MEGA_MKDIR_FILE_NAME=${SCRIPT_CONF[MEGA_MKDIR_FILE_NAME]}
MT_MEGA_DF=${SCRIPT_CONF[MT_MEGA_DF]}
SYS_LOG=${SCRIPT_CONF[SYS_LOG]}
LOG=${SCRIPT_CONF[LOG]}
BAK_DIR=${SCRIPT_CONF[BAK_DIR]}
MEGA_BACKUP_DIR=${SCRIPT_CONF[MEGA_BACKUP_DIR]}
FORGET_OPT=''
MYSQL_TEST_DB=${SCRIPT_CONF[MYSQL_TEST_DB]}
MYSQL_TEST_CNF=${SCRIPT_CONF[MYSQL_TEST_CNF]}
TEST_USER=${SCRIPT_CONF[TEST_USER]}
TEST_GPG=${SCRIPT_CONF[TEST_USER]}
OPT_EMAIL='y'

# done with config array so lets free up the memory
unset SCRIPT_CONF

usage() { echo "$(basename $0) usage:" && grep "[[:space:]].)\ #" $0 | sed 's/#//' | sed -r 's/([a-z])\)/-\1/'; exit 0; }
[ $# -eq 0 ] && usage
while getopts ":hvu:d:a:b:g:i:o:s:f:m:n:r:" arg; do
  case $arg in
    u) # Required: Specify -u the Unix user to do the database backup for.
        USER="${OPTARG}"
        ;;
    d) # Required: Specify -d the name of the database to be backed up to Mega.nz.
        DB_NAME="${OPTARG}"
        ;;
    a) # Optional: Specify -a for age that represents the number of days as a positive integer before todays date to delete files older then from Mega.nz.
        DAYS_TO_KEEP_BACKUP="${OPTARG}"
        ;;
    b) # Optional: Specify -b for location of backup directory on the local server
        BAK_DIR="${OPTARG}"
        ;;
    g) # Optional: Specify -g the gpg owner of the publick key to use for encryption. If encryption is turned on and -g option is not set then .mega_scriptsrc must have the value set for GPG_OWNER
        GPG_OWNER="${OPTARG}"
        ;;
    i) # Optional: Specify -i the configuration file to use that contain the credentials for the Mega.nz account you want to access.
        CURRENT_CONFIG="${OPTARG}"
        ;;
    o) # Optional: Specify -o the output option Default log. Can be t for terminal. Can be s for silent
        LOG="${OPTARG}"
        ;;
    s) # Optional: Specify -s the output option System log. This is the log for high level errors. Can be t for terminal. Can be s for silent
        SYS_LOG="${OPTARG}"
        ;;
    f) # Optional: Specify -f the options that can to ignore and forget checking. Can be u for user, c for config and/or d for database. EG: -f 'cd' would ignore checking if mysql config and database exist.
        FORGET_OPT="${OPTARG}"
        ;;
    m) # Optional: Specify -m the option for email on error. y for send on error and n for no send email on error. .mega_scriptsrc must be configured for email to send.
        OPT_EMAIL="${OPTARG}"
        ;;
    n) # Optional: Specify -n the name of the server used in logs both locally and in path name on mega.nz. If this flag is not set then SERVER_NAME must be set in .mega_scriptsrc
        SERVER_NAME="${OPTARG}"
        ;;
    r) # Optional: Specify -r the directory on the mega.nz server to save the backup in.
        MEGA_BACKUP_DIR="${OPTARG}"
        ;;
    v) # -v Display version info
        echo "$(basename $0) version:${MS_VERSION}"
        exit 0
        ;;
    h | *) # -h Display help.
        echo 'For online help visit: https://amourspirit.github.io/mega_scripts/mega_db_save_uploadsh.html'
        usage
        exit 0
        ;;
  esac
done

# the follow vars are eval in case they contain other expandable vars such as $HOME or ${USER}
SERVER_NAME=$(eval echo ${SERVER_NAME})
BAK_DIR=$(eval echo ${BAK_DIR})
LOG=$(eval echo ${LOG})
SYS_LOG=$(eval echo ${SYS_LOG})
OPT_EMAIL=$(eval echo ${OPT_EMAIL})
MEGA_BACKUP_DIR=$(eval echo ${MEGA_BACKUP_DIR})
CURRENT_CONFIG=$(eval echo ${CURRENT_CONFIG})
LOG_SEP=$(eval echo ${LOG_SEP})
MT_MEGA_DF=$(eval echo ${MT_MEGA_DF})

if [[ -n "${SYS_LOG}" ]]; then
    if [[ "${SYS_LOG}" = 't' ]]; then
        # redirect to terminal output
        SYS_LOG=/dev/stdout
    elif [[ "${SYS_LOG}" = 's' ]]; then
        # redirect to null output
        SYS_LOG=2>/dev/null
    else
        # test to see if the log exits
        if [[ -f "${SYS_LOG}" ]]; then
            # log does exist
            # see if we have write access to it
            if ! [[ -w "${SYS_LOG}" ]]; then
                # no write access to log file
                # exit with error code 3
                echo "No write access log file '${SYS_LOG}'. Ensure you have write privileges. Exit Code: 3"
                exit 3
            fi
        else
            # log does not exist see if we can create it
            mkdir -p "$(dirname ${SYS_LOG})"
            if [[ $? -ne 0 ]]; then
                # unable to create log
                # exit with error code 4
                echo "Unable to create log file '${SYS_LOG}'. Ensure you have write privileges. Exit Code: 4"
                exit 4
            fi
            touch "${SYS_LOG}"
            if [[ $? -ne 0 ]]; then
                # unable to create log
                # exit with error code 4
                echo "Unable to create log file '${SYS_LOG}'. Ensure you have write privileges. Exit Code: 4"
                exit 4
            fi
        fi
    fi
fi

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

if [[ -n $FORGET_OPT ]]; then
    case "$FORGET_OPT" in 
    c | C)
        # do not check for mysql config file exist
        MYSQL_TEST_CNF=false
        ;;
    d | D)
        # do not check for mysql database exist
        MYSQL_TEST_DB=false
        ;;
    u | U)
        # do not check for mysql database exist
        TEST_USER=false
        ;;
    g | G)
        # do not check for gpg
        TEST_GPG=false
    esac
fi

SEND_MAIL_CLIENT="$(command -v sendmail)"

IS_SENDING_MAIL_ON_ERROR=false

if [[ $OPT_EMAIL = 'y' ]]; then
    # read from parameters and potentially override configuration
    SEND_EMAIL_ON_ERROR=true
fi

if [[ "$SEND_EMAIL_ON_ERROR" = true && -x "$(command -v sendmail)"  && -n "$SEND_EMAIL_TO" && -n "$SEND_EMAIL_FROM" ]]; then
    IS_SENDING_MAIL_ON_ERROR=true
fi
# if log is not supplied then redirect to stdout
if [[ -z $SYS_LOG ]]; then
  SYS_LOG=/dev/stdout
fi

if ! [ -x "$(command -v bzip2)" ]; then
    echo "${DATELOG} ${LOG_ID} bzip2 not installed." >> ${LOG}
    echo "${DATELOG} ${LOG_ID} You must install bzip2 to use '${THIS_SCRIPT}'. Exit Code: 60" >> ${LOG}
    echo "${LOG_SEP}" >> ${SYS_LOG}
    echo "" >> ${SYS_LOG}
    if [[ "$IS_SENDING_MAIL_ON_ERROR" = true ]]; then
        EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 5 ${SYS_LOG}) \n\n Log File: '${SYS_LOG}'")
        ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
    fi
    exit 60
fi



if [[ "$TEST_USER" = true ]]; then
    # USER is used for log file, backup dir and Mega backup dir.
    # If the defaults are overriden in .mega_scriptsrc then it is not necessary to test for user.
    if [ -z "$USER" ]; then
        echo "${LOG_SEP}" >> ${SYS_LOG}
        echo "${DATELOG} ${LOG_ID} No argument for user supplied for user! Exiting! Exit Code 20" >> ${SYS_LOG}
        echo "${LOG_SEP}" >> ${SYS_LOG}
        echo "" >> ${SYS_LOG}
        if [[ "$IS_SENDING_MAIL_ON_ERROR" = true ]]; then
            EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 4 ${SYS_LOG}) \n\n Log File: '${SYS_LOG}'")
            ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
        fi
        exit 20
    fi
    USER_ID=$(id -u "${USER}" &>/dev/null)
    # $? is 0 if found and 1 if not found for id -u user
    if [[ $? -ne 0 ]]; then
        echo "${LOG_SEP}" >> ${SYS_LOG}
        echo "${DATELOG} ${LOG_ID} '${USER}' does Not Exit. Unable to continue: Exit Code: 53" >> ${SYS_LOG}
        echo "${LOG_SEP}" >> ${SYS_LOG}
        echo "" >> ${SYS_LOG}

        if [[ "$IS_SENDING_MAIL_ON_ERROR" = true ]]; then
            EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 4 ${SYS_LOG}) \n\n Log File: '${SYS_LOG}'")
            ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
        fi
        exit 53
    fi
    # done with USER_ID
    unset USER_ID
fi

echo "${LOG_SEP}" >> ${LOG}

if [ -z "$DB_NAME" ]; then
    echo "${DATELOG} ${LOG_ID} No argument for -d for database! Exiting" >> ${LOG}
    echo "${DATELOG} ${LOG_ID} No argument for user supplied for database! Exit Code: 21" >> ${LOG}
    echo "${LOG_SEP}" >> ${LOG}
    echo "" >> ${LOG}
    if [[ "$IS_SENDING_MAIL_ON_ERROR" = true ]]; then
        EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 5 ${LOG}) \n\n Log File: '${LOG}'")
        ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
    fi
    exit 21
fi


DB_NAME_NEW=$DATELOG"_$DB_NAME"
DB_FILE_SQL=$BAK_DIR/$DB_NAME_NEW".sql"
DB_FILE=$DB_FILE_SQL".bz2"
LOCK_FILE="/tmp/mega_backup_db_lock"
SCRIPT_DIR=$(dirname "$0")
MEGA_DEL_OLD_SCRIPT=$SCRIPT_DIR"/"$MEGA_DEL_OLD_NAME
MEGA_UPLOAD_FILE_SCRIPT=$SCRIPT_DIR"/"$MEGA_UPLOAD_FILE_NAME
MEGA_EXIST_FILE_SCRIPT=$SCRIPT_DIR"/"$MEGA_EXIST_FILE_NAME
MEGA_MKDIR_FILE_SCRIPT=$SCRIPT_DIR"/"$MEGA_MKDIR_FILE_NAME
MSD="$(command -v mysqldump)"
BASH="$(command -v bash)"
MYSQL_DIR="/var/lib/mysql"
CURRENT_CONFIG=""
HAS_CONFIG=0
OUTPUT_FILE=$DB_FILE

RE_INTEGER='^[0-9]+$'

if [[ "$ENCRYPT_OUTPUT" = true ]]; then
    # test for null even if TEST_GPG is false
    if [[ -z $GPG_OWNER ]]; then
        # fatal error GPG_OWNER must be set for enryption
        echo "${LOG_SEP}" >> ${LOG}
        echo "${DATELOG} ${LOG_ID} null value, config file 'GPG_OWNER' of .mega_scriptrc or -g option must be set! Exit Code: 116" >> ${LOG}
        echo "${LOG_SEP}" >> ${LOG}
        echo "" >> ${LOG}
        if [[ "$IS_SENDING_MAIL_ON_ERROR" = true ]]; then
            EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 4 ${LOG}) \n\n Log File: '${LOG}'")
            ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
        fi
        exit 116
    fi
    # test GPG_OWNER is set
    if [[ "$TEST_GPG" = true ]]; then
        
        if ! GpgPubKeyExist "$GPG_OWNER"; then
            # fatal error GPG_OWNER must be set for enryption
            echo "${LOG_SEP}" >> ${LOG}
            echo "${DATELOG} ${LOG_ID} Public Key for '${GPG_OWNER}' not found. Config file 'GPG_OWNER' of .mega_scriptrc or -g option must be set and must be a valid GPG Public Key! Exit Code: 117" >> ${LOG}
            echo "${LOG_SEP}" >> ${LOG}
            echo "" >> ${LOG}
            if [[ "$IS_SENDING_MAIL_ON_ERROR" = true ]]; then
                EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 4 ${LOG}) \n\n Log File: '${LOG}'")
                ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
            fi
            exit 117
        fi
    fi
    
    OUTPUT_FILE=$OUTPUT_FILE".gpg"
fi

OUTPUT_FILE_NAME=$(basename ${OUTPUT_FILE})

if [[ -n "$CURRENT_CONFIG" ]]; then
    # Argument is given for default configuration for that contains user account and password
    test -r "${CURRENT_CONFIG}"
    if [ $? -ne 0 ]; then
        echo "${LOG_SEP}" >> ${LOG}
        echo "${DATELOG} ${LOG_ID} Config file '${CURRENT_CONFIG}' does not exist or can not gain read access! Exit Code: 111" >> ${LOG}
        echo "${LOG_SEP}" >> ${LOG}
        echo "" >> ${LOG}
        if [[ "$IS_SENDING_MAIL_ON_ERROR" = true ]]; then
            EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 4 ${LOG}) \n\n Log File: '${LOG}'")
            ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
        fi
        exit 111
    fi
fi
if [ ! -z "$CURRENT_CONFIG" ]; then
  HAS_CONFIG=1
fi
if [[ -z $SERVER_NAME ]] ; then
    echo "${DATELOG} ${LOG_ID} SERVER_NAME is absent or empty from configuration! Exit Code: 73" >> ${LOG}
    echo "${LOG_SEP}" >> ${LOG}
    echo "" >> ${LOG}
    if [[ "$IS_SENDING_MAIL_ON_ERROR" = true ]]; then
        EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: Bad Server Name ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 4 ${LOG}) \n\n Log File: '${LOG}'")
        ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
    fi
    exit 73
fi
if ! [[ $DAYS_TO_KEEP_BACKUP =~ $RE_INTEGER ]] ; then
    echo "${DATELOG} ${LOG_ID} Invalid Integer for Config value DAYS_TO_KEEP_BACKUP. Must be a postitive integer! Exit Code: 73" >> ${LOG}
    echo "${LOG_SEP}" >> ${LOG}
    echo "" >> ${LOG}
    if [[ "$IS_SENDING_MAIL_ON_ERROR" = true ]]; then
        EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 4 ${LOG}) \n\n Log File: '${LOG}'")
        ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
    fi
    exit 73
fi
if [[ "$MYSQL_TEST_DB" = true ]]; then
    # test to see if MySql database exist as a folder database if not assume database does not exit
    # https://stackoverflow.com/questions/7364709/bash-script-check-if-mysql-database-exists-perform-action-based-on-result#7364807
    test -d "$MYSQL_DIR/$DB_NAME"
    if [ $? -ne 0 ]; then
        echo "${DATELOG} ${LOG_ID} '$DB_NAME' does Not Exit. Unable to continue: Exit Code: 52" >> ${LOG}
        echo "${LOG_SEP}" >> ${LOG}
        echo "" >> ${LOG}
        if [[ "$IS_SENDING_MAIL_ON_ERROR" = true ]]; then
            EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 4 ${LOG}) \n\n Log File: '${LOG}'")
            ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
        fi
        exit 52
    fi
fi

if [[ "$MYSQL_TEST_CNF" = true ]]; then
    test -r ~/.my.cnf
    if [ $? -ne 0 ]; then
        echo "${DATELOG} ${LOG_ID} ~/.my.cnf must be set up for MysqlDump to do its job. Unable to continue: Exit Code: 50" >> ${LOG}
        echo "${LOG_SEP}" >> ${LOG}
        echo "" >> ${LOG}
        if [[ "$IS_SENDING_MAIL_ON_ERROR" = true ]]; then
            EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 4 ${LOG}) \n\n Log File: '${LOG}'")
            ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
        fi
        exit 50
    fi
fi


if [[ "$MEGA_ENABLED" = true && $HAS_CONFIG -eq 0 ]]; then
    # no config has been passed into script. check and see if the default exist
    test -r ~/.megarc
    if [ $? -ne 0 ];then
        echo "${DATELOG} ${LOG_ID} ~/.megarc must be set up and readable by current to upload to mega when -i is omitted. Unable to continue: Exit Code: 51" >> ${LOG}
        echo "${LOG_SEP}" >> ${LOG}
        echo "" >> ${LOG}
        if [[ "$IS_SENDING_MAIL_ON_ERROR" = true ]]; then
            EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 4 ${LOG}) \n\n Log File: '${LOG}'")
            ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
        fi
        exit 51
    fi
fi
if [[ -d "$BAK_DIR" ]]; then
    # directory already exist. now check for write premissions
    if ! [[ -w "$BAK_DIR" ]]; then
        echo "${DATELOG} ${LOG_ID} Criticial error, unable to write to ${BAK_DIR}. Lacking write premissions. Unable to continue: Exit Code: 119" >> ${LOG}
        echo "${LOG_SEP}" >> ${LOG}
        echo "" >> ${LOG}
        if [[ "$IS_SENDING_MAIL_ON_ERROR" = true ]]; then
            EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 4 ${LOG}) \n\n Log File: '${LOG}'")
            ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
        fi
        exit 119

    fi
else
    # make the backup directory if it does not exist
    mkdir -p "$BAK_DIR" 2>/dev/null
    if [[ $? -ne 0 ]]; then
        # there was a problem creating backup directory. Critical error
        if [ $? -ne 0 ];then
            echo "${DATELOG} ${LOG_ID} Criticial error, unable to create or access directory to place backup in. Unable to continue: Exit Code: 118" >> ${LOG}
            echo "${LOG_SEP}" >> ${LOG}
            echo "" >> ${LOG}
            if [[ "$IS_SENDING_MAIL_ON_ERROR" = true ]]; then
                EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 4 ${LOG}) \n\n Log File: '${LOG}'")
                ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
            fi
            exit 118
        fi
    fi
fi

# Checking lock file
test -r "${LOCK_FILE}"
if [ $? -eq 0 ];then
    echo "${DATELOG} ${LOG_ID} There is another mega backup database process running! Exit Code: 100" >> ${LOG}
    echo "${LOG_SEP}" >> ${LOG}
    echo "" >> ${LOG}
    if [[ "$IS_SENDING_MAIL_ON_ERROR" = true ]]; then
        EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 4 ${LOG}) \n\n Log File: '${LOG}'")
        ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
    fi
    exit 100
fi

cd ${BAK_DIR}

echo "${DATELOG} ${LOG_ID} Generating '${OUTPUT_FILE}' from database '${DB_NAME}'." >> ${LOG}
if [[ "$ENCRYPT_OUTPUT" = true ]]; then
    ${MSD} -u ${DB_USER} -h localhost -a ${DB_NAME} | bzip2  > ${DB_FILE} && gpg --encrypt --recipient "$GPG_OWNER" ${DB_FILE}
    echo "${DATELOG} ${LOG_ID} '${DB_FILE}' has been encrypted using gpg as'${OUTPUT_FILE}'." >> ${LOG}
else
    ${MSD} -u ${DB_USER} -h localhost -a ${DB_NAME} | bzip2  > ${DB_FILE}
    echo "${DATELOG} ${LOG_ID} gpg encryption has been disabled in the script." >> ${LOG}
fi
echo "${DATELOG} ${LOG_ID} Generated '${OUTPUT_FILE}' from database '${DB_NAME}'." >> ${LOG}
if [[ "$DELETE_BZ2_FILE" = true ]]; then
    rm -f ${DB_FILE}
    echo "${DATELOG} ${LOG_ID} Delete bz2 file is enabled and '${DB_FILE}' has been deleted from '${BAK_DIR}'." >> ${LOG}
else
    echo "${DATELOG} ${LOG_ID} Delete bz2 file is disabled and '${DB_FILE}' is still in '${BAK_DIR}'." >> ${LOG}
fi

# Create the path to upload to on mega if it does not exist
if [[ "$MEGA_ENABLED" = true ]]; then
    echo "${DATELOG} ${LOG_ID} Checking mega.nz path to see if '${MEGA_BACKUP_DIR}' directory exist. Will created if not." >> ${LOG}
    if [[ $HAS_CONFIG -eq 0 ]]; then
        # No argument is given for default configuration for that contains user account and password
        ${BASH} "${MEGA_MKDIR_FILE_SCRIPT}" -p "${MEGA_BACKUP_DIR}"
    else
        # Argument is given for default configuration that contains user account and password
        ${BASH} "${MEGA_MKDIR_FILE_SCRIPT}" -p "${MEGA_BACKUP_DIR}" -i "${CURRENT_CONFIG}"
    fi
    EXIT_CODE=$?
    if [[ $EXIT_CODE -ne 0 ]]; then
        # there was a problem running the script
        echo "${DATELOG} ${LOG_ID} There was an issue running script '${MEGA_MKDIR_FILE_NAME}'! Exit Code: ${EXIT_CODE}" >> ${LOG}
        echo "${LOG_SEP}" >> ${LOG}
        rm -f "${LOCK_FILE}"
        if [[ "$IS_SENDING_MAIL_ON_ERROR" = true ]]; then
            EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 4 ${LOG}) \n\n Log File: '${LOG}'")
            ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
        fi
        exit $EXIT_CODE
    fi
    if [[ "$MEGA_DELETE_OLD_BACKUPS" = true ]]; then
         # Remove any expired database backup files
        if [[ $HAS_CONFIG -eq 0 ]]; then
            # No argument is given for default configuration for that contains user account and password
            ${BASH} "${MEGA_DEL_OLD_SCRIPT}" -p "${MEGA_BACKUP_DIR}" -a "${DAYS_TO_KEEP_BACKUP}" -o "${LOG}" -d "${DATELOG}"
        else
            # Argument is given for default configuration that contains user account and password
            ${BASH} "${MEGA_DEL_OLD_SCRIPT}" -p "${MEGA_BACKUP_DIR}" -a "${DAYS_TO_KEEP_BACKUP}" -o "${LOG}" -d "${DATELOG}" -i "${CURRENT_CONFIG}"
        fi
        EXIT_CODE=$?
        if [[ $EXIT_CODE -ne 0 ]]; then
            # there was a problem running the script
            echo "${DATELOG} ${LOG_ID} There was an issue running script '${MEGA_DEL_OLD_NAME}'! Exit Code: ${EXIT_CODE}" >> ${LOG}
            echo "${LOG_SEP}" >> ${LOG}
            rm -f "${LOCK_FILE}"
            if [[ "$IS_SENDING_MAIL_ON_ERROR" = true ]]; then
                EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 3 ${LOG}) \n\n Log File: '${LOG}'")
                ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
            fi
            exit $EXIT_CODE
        fi
    fi
    # Send new backup to mega.nz
    if [[ $HAS_CONFIG -eq 0 ]]; then
        # No argument is given for default configuration for that contains user account and password
        ${BASH} "${MEGA_UPLOAD_FILE_SCRIPT}" -p "${MEGA_BACKUP_DIR}" -l "${OUTPUT_FILE}" -o "${LOG}" -d "${DATELOG}"
    else
        # Argument is given for default configuration that contains user account and password
        ${BASH} "${MEGA_UPLOAD_FILE_SCRIPT}" -p "${MEGA_BACKUP_DIR}" -l "${OUTPUT_FILE}" -o "${LOG}" -d "${DATELOG}" -i "${CURRENT_CONFIG}"
    fi
    EXIT_CODE=$?
    if [[ $EXIT_CODE -ne 0 ]]; then
        # there was a problem running the script
        echo "${DATELOG} ${LOG_ID} There was an issue running script '${MEGA_UPLOAD_FILE_NAME}': Exit Code: ${EXIT_CODE}" >> ${LOG}
        echo "${LOG_SEP}" >> ${LOG}
        rm -f "${LOCK_FILE}"
        if [[ "$IS_SENDING_MAIL_ON_ERROR" = true ]]; then
            EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 3 ${LOG}) \n\n Log File: '${LOG}'")
            ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
        fi
        exit $EXIT_CODE
    fi
    #confirm new file is on mega.nz
    echo "${DATELOG} ${LOG_ID} Checking mega.nz to see if backup has made it." >> ${LOG}
    if [[ -z "$CURRENT_CONFIG" ]]; then
        # No argument is given for default configuration for that contains user account and password
        ${BASH} "${MEGA_EXIST_FILE_SCRIPT}" -p "${MEGA_BACKUP_DIR}/${OUTPUT_FILE_NAME}"
    else
        # Argument is given for default configuration that contains user account and password
        ${BASH} "${MEGA_EXIST_FILE_SCRIPT}" -p "${MEGA_BACKUP_DIR}/${OUTPUT_FILE_NAME}" -i "${CURRENT_CONFIG}"
    fi
    EXIT_CODE=$?
    if [[ $EXIT_CODE -ne 3 ]]; then
        # code 3 for this script means it found file.
        # there was a problem running the script
        echo "${DATELOG} ${LOG_ID} There was an issue running script '${MEGA_EXIST_FILE_NAME}'. Script exited with code '${EXIT_CODE}'! Exit Code: 30" >> ${LOG}
        echo "${LOG_SEP}" >> ${LOG}
        rm -f "${LOCK_FILE}"
        if [[ "$IS_SENDING_MAIL_ON_ERROR" = true ]]; then
            EMAIL_MSG=$(echo -e "To: ${SEND_EMAIL_TO}\nFrom: ${SEND_EMAIL_FROM}\nSubject: ${SERVER_NAME} ${DATELOG} - ERROR RUNNING SCRIPT '${THIS_SCRIPT}' \n\n Log Tail:\n $(tail -n 3 ${LOG}) \n\n Log File: '${LOG}'")
            ${SEND_MAIL_CLIENT} -t <<< "$EMAIL_MSG"
        fi
        exit 30
    else
        echo "${DATELOG} ${LOG_ID} File ${OUTPUT_FILE_NAME} has made it onto mega.nz" >> ${LOG}
    fi
    if [[ "$DELETE_LOCAL_BACKUP" = true ]]; then
        #delete local file
        rm -f "${OUTPUT_FILE}"
        echo "${DATELOG} ${LOG_ID} Local file ${OUTPUT_FILE_NAME} has been deleted." >> ${LOG}
    fi
    if ! [ -x "$(command -v ${MT_MEGA_DF})" ]; then
        echo "${DATELOG} ${LOG_ID} You have not enabled MEGA Storage usage." >> ${LOG}
        echo "${DATELOG} ${LOG_ID} You need to install megatools from http://megatools.megous.com or properly configure .mega_scriptsrc to point to the megadf location! Exit Code: 105" >> ${LOG}
        echo "${DATELOG} ${LOG_ID} MEGA storage usage failed" >> ${LOG}
        echo "${LOG_SEP}" >> ${LOG}
        echo "" >> ${LOG}
        # Clean up and exit
        # remove lock file
        rm -f "${LOCK_FILE}"
        exit 105
    fi
    # log the current space on mega.nz account
    if [[ $HAS_CONFIG -eq 0 ]]; then
        # No argument is given for default configuration for that contains user account and password
        # tr will remove the line breaks in this case and replace with a space to get the output on one line
        CURRENT_SPACE=$(${MT_MEGA_DF} --human | tr '\n' ' ')
    else
        # Argument is given for default configuration that contains user account and password
        CURRENT_SPACE=$(${MT_MEGA_DF} --config "$CURRENT_CONFIG" --human | tr '\n' ' ')
    fi
    echo "${DATELOG} ${LOG_ID} ${CURRENT_SPACE}" >> ${LOG}
else
    echo "${DATELOG} ${LOG_ID} Mega is currently disabled in scritp" >> ${LOG}
fi

# Finish up
echo "${DATELOG} ${LOG_ID} Normal Exit! Exit Code: 0" >> ${LOG}
echo "${LOG_SEP}" >> ${LOG}
echo "" >> ${LOG}
# Clean up and exit
rm -f "${LOCK_FILE}"
exit 0
