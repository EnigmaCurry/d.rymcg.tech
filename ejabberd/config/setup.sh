#!/bin/bash

CONFIG_DIR=/home/ejabberd/conf/${EJABBERD_HOST}

create_config() {
    TEMPLATE=/template/ejabberd.template.yml
    CONFIG=${CONFIG_DIR}/ejabberd.yml

    if [[ ! -f ${CONFIG} ]]; then
        echo "No config file found. Generating new config ..."
        mkdir -p ${CONFIG_DIR}
        cat ${TEMPLATE} | envsubst > ${CONFIG}
        echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${CONFIG}"
    else
        echo "[ * ] Using existing config file from volume: ${CONFIG}"
    fi
    [[ $PRINT_CONFIG == true ]] && cat ${CONFIG}
}


fix_permissions() {
    # ejabberd runs as uid 9000 gid 9000
    chown -R 9000:9000 ${CONFIG_DIR}
}

create_config
fix_permissions
