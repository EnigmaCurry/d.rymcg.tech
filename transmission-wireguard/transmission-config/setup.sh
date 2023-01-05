#!/bin/bash

set -e
TEMPLATE_DIR=/template
CONFIG_DIR=/config

create_config() {
    rm -rf ${CONFIG_DIR}/*
    mkdir -p ${CONFIG_DIR}
    cat ${TEMPLATE_DIR}/settings.json | envsubst > ${CONFIG_DIR}/settings.json
    echo "[ ! ] GENERATED NEW CONFIG FILE :::  ${CONFIG_DIR}/settings.json"
}

create_config
