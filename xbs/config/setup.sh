#!/bin/bash

TEMPLATE=/template/settings.template.json
CONFIG=/data/settings.json

create_config() {
    mkdir -p $(dirname ${CONFIG})
    cat ${TEMPLATE} | envsubst > ${CONFIG}
    echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${CONFIG}"

    [[ $PRINT_CONFIG == true ]] && cat ${CONFIG}
}

create_config
