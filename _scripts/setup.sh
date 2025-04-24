#!/bin/bash

## Configuration menu helper script for the root d.rymcg.tech Makefile.

BIN=${ROOT_DIR}/_scripts
source ${BIN}/funcs.sh
set -e

main_menu() {
    base_config
    while :
    do
        clear
        separator '###' 60 "${DOCKER_CONTEXT}"
        wizard menu --cancel-code=2 --once "d.rymcg.tech:" \
               "Root Config = make root-config" \
               "Traefik Config = make -C ${ROOT_DIR}/traefik config" \
               "Exit (ESC) = exit 2"
        local EXIT_CODE=$?
        if [[ "${EXIT_CODE}" == "2" ]]; then
            exit 0
        fi
    done
}

base_config() {
    ## Make new .env if it doesn't exist:
    test -f ${ROOT_DIR}/${ROOT_ENV} || cp ${ROOT_DIR}/.env-dist ${ROOT_DIR}/${ROOT_ENV}
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    ##Script is being run directly
    echo
    if [[ "$#" -lt 1 ]]; then
        fault "Wrong number of arguments. Try running \`make config\` instead."
    fi

    check_var ENV_FILE
    check_var DOCKER_CONTEXT

    $@
fi

