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

# Categories
process_categories() {
    touch /config/.config_hash
    cat /template/healthcheck.sh > /config/healthcheck.sh
    chmod +x /config/healthcheck.sh
    # remove comments and blank lines from categories.json
    sed '/^\/\//d; /^$/d' "${TEMPLATE_DIR}/categories.json" > "${CONFIG_DIR}/categories.json"
}

process_categories
