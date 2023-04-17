#!/bin/bash

# echo_color(color, text)
echo_color() {
    # echo "Color is $1"
    # echo "Text is $@"
    echo -e "${1}${@}\033[0m"
}

# ANSICOLORS AS EXPORTS
#
# Usage:
#
# <in some other shell script...>
#
# source vars-ansicolors.sh
# echo -e "This is ${ANSI_BOLD}${ANSI_WHITE}BOLD WHITE ${ANSI_ON_RED}ON A RED BACKGROUND${ANSI_OFF}"
#
# Or, more tersely,
#
# . vars-ansicolors.sh
# echo -e "This is $ANSI_BOLD$ANSI_WHITEBOLD WHITE ${ANSI_ON_RED}ON A RED BACKGROUND$ANSI_OFF"

export ANSI_OFF="\\033[0m"
export ANSI_DIM="\\033[2m"
export ANSI_BOLD="\\033[1m"

export ANSI_BLACK="\\033[30m"
export ANSI_RED="\\033[31m"
export ANSI_GREEN="\\033[32m"
export ANSI_YELLOW="\\033[33m"
export ANSI_BLUE="\\033[34m"
export ANSI_MAGENTA="\\033[35m"
export ANSI_CYAN="\\033[36m"
export ANSI_WHITE="\\033[37m"

export ANSI_LIGHT_BLACK="\\033[90m"
export ANSI_LIGHT_RED="\\033[91m"
export ANSI_LIGHT_GREEN="\\033[92m"
export ANSI_LIGHT_YELLOW="\\033[99m"
export ANSI_LIGHT_BLUE="\\033[94m"
export ANSI_LIGHT_MAGENTA="\\033[95m"
export ANSI_LIGHT_CYAN="\\033[96m"
export ANSI_LIGHT_WHITE="\\033[97m"

export ANSI_ON_BLACK="\\033[40m"
export ANSI_ON_RED="\\033[41m"
export ANSI_ON_GREEN="\\033[42m"
export ANSI_ON_YELLOW="\\033[43m"
export ANSI_ON_BLUE="\\033[44m"
export ANSI_ON_MAGENTA="\\033[45m"
export ANSI_ON_CYAN="\\033[46m"
export ANSI_ON_WHITE="\\033[47m"

export ANSI_ON_LIGHT_BLACK="\\033[100m"
export ANSI_ON_LIGHT_RED="\\033[101m"
export ANSI_ON_LIGHT_GREEN="\\033[102m"
export ANSI_ON_LIGHT_YELLOW="\\033[109m"
export ANSI_ON_LIGHT_BLUE="\\033[104m"
export ANSI_ON_LIGHT_MAGENTA="\\033[105m"
export ANSI_ON_LIGHT_CYAN="\\033[106m"
export ANSI_ON_LIGHT_WHITE="\\033[107m"
