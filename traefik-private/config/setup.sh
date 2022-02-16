#!/bin/bash

TEMPLATE_DIR=/template
CONFIG_DIR=/data/config

create_config() {
    rm -rf /data/config
    mkdir -p ${CONFIG_DIR}
    for conf in /template/*.{yaml,yml,toml}; do
        [ -e "${conf}" ] || continue
        CONF=${CONFIG_DIR}/$(basename ${conf})
        cat ${conf} | envsubst > ${CONF}
        echo "[ ! ] GENERATED NEW CONFIG FILE :::  ${CONF}"
    done
}

create_config
