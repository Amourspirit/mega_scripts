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
# Version 1.2.2.0
# File Name: mega_mkdir.sh
# Github: https://github.com/Amourspirit/mega_scripts
# Help: https://amourspirit.github.io/mega_scripts/mega_mkdirsh.html
# 
# This script will make directories if they do not exist for a path.
# This is the mega.nz equivalent of mkdir -p for UNIX
#    Eg: ./mega_mkdir.sh "/testdir/2018/bigtest/deep/deeper/bottom"
#
# Optional parameter 1: pass in the folder or file to see if exist
# Optional parameter 2: pass in the configuration file that contains the account information for mega.nz. Defaults to ~/.megarc
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

if ! [ -x "$(command -v megamkdir)" ]; then
   exit 115
fi

BASH="/bin/bash"
SCRIPT_DIR=$(dirname "$0")
MEGA_DEFAULT_ROOT="/Root"
MEGA_EXIST_FILE_NAME="mega_dir_file_exist.sh"
MEGA_EXIST_FILE_SCRIPT=$SCRIPT_DIR"/"$MEGA_EXIST_FILE_NAME
CURRENT_CONFIG=""
HAS_CONFIG=0
DIR=""
NEW_DIR=""
EXIT_CODE=0
if [ -z "$1" ]; then
    # No argument supplied for path! Exiting
    exit 40
else
    DIR=$1
fi

if [[ -n "$2" ]]; then
    # Argument is given for default configuration for that contains user account and password
    CURRENT_CONFIG="$2"
    test -r "${CURRENT_CONFIG}"
    if [ $? -ne 0 ]; then
        #Config file does not exist or can not gain read access! Exit Code: 111
        exit 111
    fi
    HAS_CONFIG=1
fi
if [[ HAS_CONFIG -eq 1 ]]; then
    ${BASH} "${MEGA_EXIST_FILE_SCRIPT}" "${DIR}" "${CURRENT_CONFIG}"
else
    ${BASH} "${MEGA_EXIST_FILE_SCRIPT}" "${DIR}"
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
        NEW_DIR="$NEW_DIR/$i"
        if [[ HAS_CONFIG -eq 1 ]]; then
            ${BASH} "${MEGA_EXIST_FILE_SCRIPT}" "${NEW_DIR}" "${CURRENT_CONFIG}"
        else
            ${BASH} "${MEGA_EXIST_FILE_SCRIPT}" "${NEW_DIR}"
        fi
        EXIST_RESULT=$?
        if [[ $EXIST_RESULT -eq 0 ]]; then
            if [[ HAS_CONFIG -eq 1 ]]; then
                megamkdir --config "${CURRENT_CONFIG}" "${MEGA_DEFAULT_ROOT}/$NEW_DIR"
            else
                megamkdir "${MEGA_DEFAULT_ROOT}/$NEW_DIR"
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