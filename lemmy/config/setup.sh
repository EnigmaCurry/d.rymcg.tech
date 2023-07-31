#!/bin/bash

CONFIG_DIR=/config

create_config() {
    TEMPLATE=/template/config.hjson
    CONFIG=${CONFIG_DIR}/config.hjson

    mkdir -p ${CONFIG_DIR}
    cat ${TEMPLATE} | envsubst > ${CONFIG}
    echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${CONFIG}"
    [[ $PRINT_CONFIG == true ]] && cat ${CONFIG}
}


create_config
