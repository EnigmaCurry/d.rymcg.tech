#!/bin/bash

CONFIG_DIR=/etc/nginx

create_config() {
    TEMPLATE=/template/nginx_internal.conf
    CONFIG=${CONFIG_DIR}/nginx.conf

    mkdir -p ${CONFIG_DIR}
    cp ${TEMPLATE} ${CONFIG}
    echo "[ ! ] GENERATED NEW NGINX CONFIG FILE ::: ${CONFIG}"
    [[ $PRINT_NGINX_CONFIG == true ]] && cat ${CONFIG}
    rm -rf ${CONFIG_DIR}/conf.d
}


create_config
