#!/bin/bash

CONFIG_DIR=/cryptpad/config

create_config() {
    TEMPLATE=/template/config.template.js
    CONFIG=${CONFIG_DIR}/config.js

    mkdir -p ${CONFIG_DIR}
    cat ${TEMPLATE} | envsubst > ${CONFIG}
    echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${CONFIG}"
    [[ $PRINT_CONFIG == true ]] && cat ${CONFIG}
}


create_config
