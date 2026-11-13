#!/bin/bash

TEMPLATE=/template/settings.template.json
CONFIG=/data/settings.json

create_config() {
    mkdir -p $(dirname ${CONFIG})
    cat ${TEMPLATE} | envsubst > ${CONFIG}
    echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${CONFIG}"

    if [[ $PRINT_CONFIG == true ]]; then
        cat ${CONFIG}
    fi
}

create_config
