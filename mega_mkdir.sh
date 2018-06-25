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
# Script to check and see if a file or folder exist on a mega.nz account
# Created by Paul Moss
# Created: 2018-05-27
# File Name: mega_mkdir.sh
# Github: https://github.com/Amourspirit/mega_scripts
# Help: https://amourspirit.github.io/mega_scripts/mega_mkdirsh.html
# 
# This script will make directories if they do not exist for a path.
# This is the mega.nz equivalent of mkdir -p for UNIX
#    Eg: ./mega_mkdir.sh -p "/testdir/2018/bigtest/deep/deeper/bottom"
#
# -p: Optional: -p pass in the Path to create if it does not exist on Mega.nz
#     Example: /bin/bash /usr/local/bin/mega_mkdir.sh -p '/testdir/2018/bigtest/deep/deeper/bottom'; echo $?
# -i: Optional: -i pass in the configuration file that contains the account information for mega.nz. Defaults to ~/.megarc
# -v: Display the current version of this script
# -h: Display script help
#
# Exit Codes
# Code  Defination
#   0   Normal Exit. No Errors Encountered.
#  40   If no argument is give for parameter one, the path to check.
#  41   If megamkdir had error creating directory
#  42   If a file was found with the same name as part of the path
# 102   megals not found. Megtools requires installing
# 111   Optional argument Param 2 was passed in but the config can not be found or we do not have read permissions
# 115   megamkdir not found. Megtools requires installing

# trims white space from input
MS_VERSION='1.3.1.0'
function trim () {
    local var=$1;
    var="${var#"${var%%[![:space:]]*}"}";   # remove leading whitespace characters
    var="${var%"${var##*[![:space:]]}"}";   # remove trailing whitespace characters
    echo -n "$var";
}

if ! [ -x "$(command -v megamkdir)" ]; then
   exit 115
fi

# create an array that contains configuration values
# put values that need to be evaluated using eval in single quotes
typeset -A SCRIPT_CONF # init array
SCRIPT_CONF=( # set default values in config array
    [MEGA_EXIST_FILE_NAME]="mega_dir_file_exist.sh"
)
if [[ -f "${HOME}/.mega_scriptsrc" ]]; then
    # make tmp file to hold section of config.ini style section in
    TMP_CONFIG_COMMON_FILE=$(mktemp)
    # SECTION_NAME is a var to hold which section of config you want to read
    SECTION_NAME="MEGA_COMMON"
    # sed in this case takes the value of SECTION_NAME and reads the setion from ~/config.ini
    sed -n '0,/'"$SECTION_NAME"'/d;/\[/,$d;/^$/d;p' "$HOME/.mega_scriptsrc" > $TMP_CONFIG_COMMON_FILE

    # test tmp file to to see if it is greater then 0 in size
    test -s "${TMP_CONFIG_COMMON_FILE}"
    if [ $? -eq 0 ]; then
    # read the input of the tmp config file line by line
        while read line; do
            if [[ "$line" =~ ^[^#]*= ]]; then
                setting_name=$(trim "${line%%=*}");
                setting_value=$(trim "${line#*=}");
                SCRIPT_CONF[$setting_name]=$setting_value
            fi
        done < "$TMP_CONFIG_COMMON_FILE"
    fi

    # release the tmp file that is contains the current section values
    unlink $TMP_CONFIG_COMMON_FILE
fi

BASH="$(command -v bash)"
SCRIPT_DIR=$(dirname "$0")
MEGA_DEFAULT_ROOT="/Root"
MEGA_EXIST_FILE_NAME=${SCRIPT_CONF[MEGA_EXIST_FILE_NAME]}
MEGA_EXIST_FILE_SCRIPT=$SCRIPT_DIR"/"$MEGA_EXIST_FILE_NAME
CURRENT_CONFIG=""
HAS_CONFIG=0
DIR=""
NEW_DIR=""
EXIT_CODE=0
usage() { echo "$(basename $0) usage:" && grep "[[:space:]].)\ #" $0 | sed 's/#//' | sed -r 's/([a-z])\)/-\1/'; exit 0; }
[ $# -eq 0 ] && usage
while getopts ":hvp:i:" arg; do
  case $arg in
    p) # Required: Specify -p the Path to create if it does not exist on Mega.nz Example: /bin/bash /usr/local/bin/mega_mkdir.sh -p '/testdir/2018/bigtest/deep/deeper/bottom'; echo $?
        DIR="${OPTARG}"
        ;;
    i) # Optional: Specify -i the configuration file to use that contain the credentials for the Mega.nz account you want to access.
        CURRENT_CONFIG="${OPTARG}"
        ;;
    v) # -v Display version info
        echo "$(basename $0) version:${MS_VERSION}"
        exit 0
        ;;
    h | *) # -h Display help.
        echo 'For online help visit: https://amourspirit.github.io/mega_scripts/mega_mkdirsh.html'
        usage
        exit 0
        ;;
  esac
done

# the follow vars are eval in case they contain other expandable vars such as $HOME or ${USER}
DIR=$(eval echo ${DIR})
CURRENT_CONFIG=$(eval echo ${CURRENT_CONFIG})

if [ -z "$DIR" ]; then
    # No argument supplied for path! Exiting
    exit 40
fi

if [[ -n "$CURRENT_CONFIG" ]]; then
    # Argument is given for default configuration for that contains user account and password
    test -r "${CURRENT_CONFIG}"
    if [ $? -ne 0 ]; then
        #Config file does not exist or can not gain read access! Exit Code: 111
        exit 111
    fi
    HAS_CONFIG=1
fi
if [[ HAS_CONFIG -eq 1 ]]; then
    ${BASH} "${MEGA_EXIST_FILE_SCRIPT}" -p "${DIR}" -i "${CURRENT_CONFIG}"
else
    ${BASH} "${MEGA_EXIST_FILE_SCRIPT}" -p "${DIR}"
fi
if [[ $? -eq 2 ]]; then
    # Directory already exist
    exit 0
fi
# if result is 0 we will continue
case $? in
    1 )
        # directory found root
        exit 0
        ;;
    2 )
        # directory found
        exit 0
        ;;
    3 )
        # file found
        exit 42
        ;;
    102 )
        #megals not found. Megtools requires installing
        exit 102
        ;;
esac
IFS='/' read -ra PARTS <<< "$DIR"
for i in "${PARTS[@]}"; do
    # process "$i"

    if [[ -n $i ]]; then
        NEW_DIR="${NEW_DIR}/$i"
        if [[ HAS_CONFIG -eq 1 ]]; then
            ${BASH} "${MEGA_EXIST_FILE_SCRIPT}" -p "${NEW_DIR}" -i "${CURRENT_CONFIG}"
        else
            ${BASH} "${MEGA_EXIST_FILE_SCRIPT}" -p "${NEW_DIR}"
        fi
        EXIST_RESULT=$?
        if [[ $EXIST_RESULT -eq 0 ]]; then
            if [[ HAS_CONFIG -eq 1 ]]; then
                megamkdir --config "${CURRENT_CONFIG}" "${MEGA_DEFAULT_ROOT}/${NEW_DIR}"
            else
                megamkdir "${MEGA_DEFAULT_ROOT}/${NEW_DIR}"
            fi
            EXIT_CODE=$?
            if [[ EXIT_CODE -ne 0 ]]; then
                #echo "Error Creating directory '$NEW_DIR' megamkdir Error Code: $EXIT_CODE"
                EXIT_CODE=41
                break
            fi
        else
            if [[ $EXIST_RESULT -ne 2 ]]; then
                # unable to continue. this part of the path is not a directory and we cannot continue.
                # most likely a file
                EXIT_CODE=42
                break
            fi
        fi
    fi
done
exit $EXIT_CODE