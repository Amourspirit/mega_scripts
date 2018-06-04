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
# Created: 2018-06-02
# Version 1.2.1.0
#
# File Name: mega_dir_file_exist.sh
# 
# This script can be used to test if mega.nz can be connected to as well.
#    Eg: ./mega_dir_file_exist.sh; echo $?
#        this will output 1 if connection was successful and 0 otherwise
#    Eg: ./mega_dir_file_exist.sh "" ~/.megarc; echo $?
#        this will output 1 if connection was successful and 0 otherwise while allowing to pass in a config file.
#
# Optional parameter 1: pass in the folder or file to see if exist
# Optional parameter 2: pass in the configuration file that contains the account information for mega.nz. Defaults to ~/.megarc
#
# Exit Codes
#     0 Directory or File not found
#     1 Directory found and is Root
#     2 Directory found
#     3 File found
#     102 megals not found. Megtools requires installing
#     111 Optional argument two was passed in but the config can not be foud or we do not have read permissions


MEGA_DEFAULT_ROOT="/Root"
MEGA_SERVER_PATH=""
CURRENT_CONFIG=""
MEGA_FILES=""
IN_ROOT=0

if ! [ -x /usr/bin/megals ]; then
   exit 102
fi
if [ -z "$1" ]; then
    # No argument for user supplied mega server path
    MEGA_SERVER_PATH=$MEGA_DEFAULT_ROOT
    IN_ROOT=1
else
    MEGA_SERVER_PATH=$MEGA_DEFAULT_ROOT"$1"
fi
if [[ ! -z "$2" ]]; then
    # Argument is given for default configuration for that contains user account and password
    CURRENT_CONFIG="$2"
    test -r "${CURRENT_CONFIG}"
    if [ $? -ne 0 ]; then
        exit 111
    fi
fi

if [[ -z "$CURRENT_CONFIG" ]]; then
    # No argument is given for default configuration for that contains user account and password
    MEGA_FILES=$(megals -l "$MEGA_SERVER_PATH")
else
    # Argument is given for default configuration that contains user account and password
    MEGA_FILES=$(megals --config "$CURRENT_CONFIG" -l "$MEGA_SERVER_PATH")
fi

if [[ -z "$MEGA_FILES" ]]; then
    #nothing returned from mggals this indicates that does not exist
    exit 0
fi

# create a tmp file to be used for exit code.
# loops do not play well well with setting var values outside the loop so we use a file
TMP_FILE_STATUS=$(mktemp)
# write 0 to the file this way if loop finds nothing then default exit code will be 0
echo 0 >> ${TMP_FILE_STATUS}

echo "$MEGA_FILES" | while read line
do
    # using awk NF (number of fields) to count from right to left to get field data.
    # using NF because not all lines suchs a root have the same number of columns before type
    # however the data we need to access is always the same form right ot left
    FILE_PATH=$(echo "$line" | awk '{print $(NF)}')
    
    if [[ $FILE_PATH != $MEGA_SERVER_PATH ]]; then
        # not a match of the file / folder we are looking for
        continue
    fi
    
    # If we have gotten this far in the loop then we have a match for file / folder
    # lets check and see if it is a file or a folder
    FILE_TYPE=$(echo "$line" | awk '{print $(NF-4)}')
    # when FILE_TYPE = 0 it is a file
    # when FILE_TYPE = 1 it is a folder
    # when FILE_TYPE = 2 it is root

    if [[ $FILE_TYPE -eq 0 ]]; then
        # clear the tmp file
        truncate -s 0 "${TMP_FILE_STATUS}"
        # exit code for file will be 3
        echo 3 >> ${TMP_FILE_STATUS}
    fi
    if [[ $FILE_TYPE -eq 1 ]]; then
        # clear the tmp file
        truncate -s 0 "${TMP_FILE_STATUS}"
        # exit code for directory will be 2
        echo 2 >> ${TMP_FILE_STATUS}
    fi
    if [[ $FILE_TYPE -eq 2 ]]; then
        # clear the tmp file
        truncate -s 0 "${TMP_FILE_STATUS}"
        # exit code for root will be 1
        echo 1 >> ${TMP_FILE_STATUS}
    fi
    break
done
FINAL_STATUS=$(cat $TMP_FILE_STATUS)
unlink $TMP_FILE_STATUS
exit $FINAL_STATUS
