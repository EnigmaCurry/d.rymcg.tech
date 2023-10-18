#!/bin/bash

## Confirm with the user - PURE BASH version
## Check env for the var YES, if it equals "yes" then bypass this confirm
test ${YES:-no} == "yes" && exit 0

default=$1; prompt=$2; question=${3:-". Proceed?"}
if [[ $default == "y" || $default == "yes" || $default == "ok" ]]; then
    dflt="Y/n"
else
    dflt="y/N"
fi

read -e -p $'\e[32m?\e[0m '"${prompt}${question} (${dflt}): " answer
answer=${answer:-${default}}

if [[ ${answer,,} == "y" || ${answer,,} == "yes" || ${answer,,} == "ok" ]]; then
    exit 0
else
    exit 1
fi
