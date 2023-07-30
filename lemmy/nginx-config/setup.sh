#!/bin/bash

CONFIG_DIR=/etc/nginx

create_config() {
    TEMPLATE=/template/nginx_internal.conf
    CONFIG=${CONFIG_DIR}/nginx_internal.conf

    mkdir -p ${CONFIG_DIR}
    cat ${TEMPLATE} | envsubst > ${CONFIG}
    echo "[ ! ] GENERATED NEW NGINX CONFIG FILE ::: ${CONFIG}"
    [[ $PRINT_NGINX_CONFIG == true ]] && cat ${CONFIG}
}


create_config
