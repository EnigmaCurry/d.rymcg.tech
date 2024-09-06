#!/bin/bash

CONFIG_DIR=/config

create_config() {
    TEMPLATE=/template/$1
    CONFIG=${CONFIG_DIR}/$1

    mkdir -p ${CONFIG_DIR}
    cat ${TEMPLATE} | envsubst > ${CONFIG}
    echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${CONFIG}"
    [[ $PRINT_CONFIG == true ]] && cat ${CONFIG}
}


create_config settings.yml
create_config limiter.toml