#!/bin/bash

CONFIG_DIR=/etc/matterbridge
CONFIG=${CONFIG_DIR}/matterbridge.toml

create_config() {
    echo "Creating new config from template (${TEMPLATE}) ..."
    mkdir -p ${CONFIG_DIR}
    rm -f ${CONFIG}
    cat /template/${TEMPLATE} | envsubst > ${CONFIG}
    echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${CONFIG}"
    [[ $PRINT_CONFIG == true ]] && cat ${CONFIG}
}

create_config
