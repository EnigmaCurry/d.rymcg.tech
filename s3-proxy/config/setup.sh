#!/bin/bash

CONFIG_DIR=/proxy/conf

create_config() {
    TEMPLATE=/template/s3-proxy.template.yml
    CONFIG=${CONFIG_DIR}/s3-proxy.yml

    mkdir -p ${CONFIG_DIR}
    cat ${TEMPLATE} | envsubst > ${CONFIG}
    echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${CONFIG}"
    if [[ $PRINT_CONFIG == true ]]; then
        cat ${CONFIG}
    fi
}


create_config
