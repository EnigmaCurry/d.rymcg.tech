#!/bin/bash

set -e
TEMPLATE_DIR=/template
CONFIG_DIR=/config/qBittorrent

create_config() {
    rm -rf ${CONFIG_DIR}/qBittorrent.conf
    mkdir -p ${CONFIG_DIR}
    if [ -f ${TEMPLATE_DIR}/qBittorrent.conf ]; then
        cat ${TEMPLATE_DIR}/qBittorrent.conf | envsubst > ${CONFIG_DIR}/qBittorrent.conf
        echo "[ ! ] GENERATED NEW CONFIG FILE :::  ${CONFIG_DIR}/qBittorrent.conf"
    else
        echo "Skipping config as ${CONFIG_DIR}/qBittorrent.conf already exists"
    fi
}

create_config

    sed '/^\/\//d; /^$/d' "${TEMPLATE_DIR}/categories.json" > "${CONFIG_DIR}/categories.json"
