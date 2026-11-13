#!/bin/bash

CONFIG_DIR=/config

create_config() {
    TEMPLATE=/template/config.hjson
    CONFIG=${CONFIG_DIR}/config.hjson

    mkdir -p ${CONFIG_DIR}
    cat ${TEMPLATE} | envsubst > ${CONFIG}
    echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${CONFIG}"
    if [[ $PRINT_CONFIG == true ]]; then
        cat ${CONFIG}
    fi
}

create_config


CONFIG_DIR=/pictrs-config

create_pictrs_config() {
    TEMPLATE=/template/config.toml
    CONFIG=${CONFIG_DIR}/config.toml

    mkdir -p ${CONFIG_DIR}
    cat ${TEMPLATE} | envsubst > ${CONFIG}
    echo "[ ! ] GENERATED NEW PICTRS CONFIG FILE ::: ${CONFIG}"
    if [[ $PRINT_CONFIG == true ]]; then
        cat ${CONFIG}
    fi
}

create_pictrs_config
