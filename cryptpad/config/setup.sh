#!/bin/bash

CONFIG_DIR=/cryptpad/config
set -e

create_config() {
    TEMPLATE=/template/config.template.js
    CONFIG=${CONFIG_DIR}/config.js
    NGINX_TEMPLATE=/template/nginx.conf
    NGINX_CONFIG=${CONFIG_DIR}/nginx.conf

    mkdir -p ${CONFIG_DIR}
    cat ${TEMPLATE} | envsubst > ${CONFIG}
    echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${CONFIG}"
    [[ $PRINT_CONFIG == true ]] && cat ${CONFIG}

    cat ${NGINX_TEMPLATE} | envsubst '${CRYPTPAD_TRAEFIK_HOST} ${CRYPTPAD_SANDBOX_DOMAIN} ${CRYPTPAD_ALLOWED_ORIGINS}' > ${NGINX_CONFIG}
    echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${NGINX_CONFIG}"
    [[ $PRINT_CONFIG == true ]] && cat ${NGINX_CONFIG}
}


create_config
exit 0
