#!/bin/sh

CONFIG_DIR=/home/node/trilium-data

create_config() {
    TEMPLATE=/template/config.ini
    CONFIG=${CONFIG_DIR}/config.ini

    mkdir -p ${CONFIG_DIR}
    cat ${TEMPLATE} | envsubst > ${CONFIG}
    chown node:node ${CONFIG}
    echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${CONFIG}"
    #[[ $PRINT_CONFIG == true ]] && cat ${CONFIG}
}

create_config

# Start TrilumNext Notes
cd /usr/src/app
./start-docker.sh
