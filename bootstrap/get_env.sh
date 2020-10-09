#!/usr/bin/env bash
###############################################################################
RED='\033[0;31m' # Red
NC='\033[0m' # No Color CAP

function get_env(){
# Local .env
if [ -f $1 ]; then
    # Load Environment Variables
    export $(cat $1 | grep -v '#' | awk '/=/ {print $1}')
else
    # Print error message
    printf("Error... $1 is not a file.\nCheck your file name or direcotry " 
            "and try again...\n")
    printf("Usage: ${RED}get_env <filename> ${NC}\n")
    exit 1
fi

}