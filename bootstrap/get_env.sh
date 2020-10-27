#!/usr/bin/env bash
###############################################################################
RED='\033[0;31m' # Red
NC='\033[0m' # No Color CAP
###############################################################################
###############################################################################
###############################################################################
function get_env(){
###############################################################################
# Local .env
if [ -f $1 ]; then
    # Load Environment Variables
    export $(cat $1 | grep -v '#' | awk '/=/ {print $1}')
else
    printf "${RED}Unable to load file. Check your input and rerun again...${NC}\n"
    exit $?
fi
    # Checking if environments have loaded

}