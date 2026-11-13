#!/bin/bash

TEMPLATE=/template/config.template.yaml
CONFIG=/data/config.yaml

create_config() {
    if [[ ! -f ${CONFIG} ]]; then
        mkdir -p $(dirname ${CONFIG})
        cat ${TEMPLATE} | envsubst > ${CONFIG}
        echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${CONFIG}"
    else
        echo "[ * ] Using existing config file from volume: ${CONFIG}"
    fi

    if [[ $PRINT_CONFIG == true ]]; then
        cat ${CONFIG}
    fi
}

create_config
