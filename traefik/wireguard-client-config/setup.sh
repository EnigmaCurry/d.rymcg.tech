#!/bin/bash

set -e
TEMPLATE_DIR=/template
CONFIG_DIR=/config

create_config() {
    rm -rf ${CONFIG_DIR}/*
    mkdir -p ${CONFIG_DIR}
    for conf in /template/*.conf; do
        [ -e "${conf}" ] || continue
        CONF=${CONFIG_DIR}/$(basename ${conf})
        if [[ -n "${TRAEFIK_VPN_CLIENT_PEER_PRESHARED_KEY}" ]]; then
            envsubst < ${conf} > ${CONF}
        else
            ## The peer has no PresharedKey; an empty one is not valid:
            grep -v '^PresharedKey' ${conf} | envsubst > ${CONF}
        fi
        chmod og-rwx ${CONF}
        echo "[ ! ] GENERATED NEW CONFIG FILE :::  ${CONF}"
    done
}

create_config
