#!/bin/bash

CONFIG_DIR=/config

create_config() {
    TEMPLATE=/template/$1
    CONFIG=${CONFIG_DIR}/$1

    mkdir -p ${CONFIG_DIR}
    cat ${TEMPLATE} | envsubst > ${CONFIG}
    echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${CONFIG}"
    if [[ $PRINT_CONFIG == true ]]; then
        cat ${CONFIG}
    fi
}


create_config settings.yml
create_config limiter.toml
