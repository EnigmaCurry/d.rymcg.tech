#!/bin/bash

set -e
TEMPLATE_DIR=/template
CONFIG_DIR=/config

create_config() {
    rm -rf ${CONFIG_DIR}/*
    mkdir -p ${CONFIG_DIR}/wg_confs
    for conf in /template/*.conf; do
        [ -e "${conf}" ] || continue
        CONF=${CONFIG_DIR}/wg_confs/$(basename ${conf})
        cat ${conf} | envsubst > ${CONF}
        chmod og-rwx ${CONF}
        echo "[ ! ] GENERATED NEW CONFIG FILE :::  ${CONF}"
    done
}

create_config
