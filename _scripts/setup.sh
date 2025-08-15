#!/bin/bash

## Configuration menu helper script for the root d.rymcg.tech Makefile.

BIN=${ROOT_DIR}/_scripts
source ${BIN}/funcs.sh
set -e

main_menu() {
    while :
    do
        if [ -f ${ROOT_DIR}/${ROOT_ENV} ]; then
            clear
            separator '###' 60 "${DOCKER_CONTEXT}"
            wizard menu --default 1 --cancel-code=2 --once "d.rymcg.tech:" \
                   "Root Config = make root-config || true" \
                   "Traefik Config = make -C ${ROOT_DIR}/traefik config || true" \
                   "Exit (ESC) = exit 2"
            local EXIT_CODE=$?
            if [[ "${EXIT_CODE}" == "2" ]]; then
                exit 0
            fi
        else
            clear
            separator '###' 60 "${DOCKER_CONTEXT}"
            wizard menu --cancel-code=2 --once "d.rymcg.tech:" \
                   "Root Config = make root-config || true" \
                   "Exit (ESC) = exit 2"
            local EXIT_CODE=$?
            if [[ "${EXIT_CODE}" == "2" ]]; then
                exit 0
            fi
        fi
    done
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

