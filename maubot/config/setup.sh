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

    [[ $PRINT_CONFIG == true ]] && cat ${CONFIG}
}

create_config
