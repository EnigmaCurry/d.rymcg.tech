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

create_tls() {
    if [[ ! -f /home/ejabberd/conf/${EJABBERD_HOST}/cert.pem ]]; then
        echo "No certificate found."
        [[ $SELF_SIGNED_TLS != true ]] && exit 1
        [[ ${#EJABBERD_HOST} < 1 ]] && echo "EJABBERD_HOST must not be blank" && exit 1

        echo "Generating 100 year self-signed certificate ..."
        mkdir -p ${CONFIG_DIR}
        openssl req -x509 -newkey rsa:4096 -nodes -keyout ${CONFIG_DIR}/key.pem -out ${CONFIG_DIR}/cert.pem -sha256 -days 36525 -subj "/CN=${EJABBERD_HOST}" -verbose
    fi
}

fix_permissions() {
    # ejabberd runs as uid 9000 gid 9000
    chown -R 9000:9000 ${CONFIG_DIR}
}

create_config
create_tls
fix_permissions
