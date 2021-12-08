#!/bin/bash

create_config() {
    TEMPLATE=/template/config.template.yaml
    CONFIG=/config/config.yaml

    if [[ ! -f ${CONFIG} ]]; then
        echo "No config file found. Generating new config ..."
        export PEPPER_KEY=$(openssl rand -base64 32)
        export COMPONENT_SECRET=$(openssl rand -base64 32)
        export DIALBACK_SECRET=$(openssl rand -base64 32)

        cat ${TEMPLATE} | envsubst > ${CONFIG}
        echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${CONFIG}"
    else
        echo "[ * ] Using existing config file from volume: ${CONFIG}"
    fi
    [[ $PRINT_CONFIG == true ]] && cat ${CONFIG}
}

create_tls() {
    if [[ ! -f /config/cert.pem ]]; then
        echo "No certificate found."
        [[ $SELF_SIGNED_TLS != true ]] && return 0
        [[ ${#JACKAL_HOST} < 1 ]] && echo "JACKAL_HOST must not be blank" && exit 1

        echo "Generating 100 year self-signed certificate ..."
        openssl req -x509 -newkey rsa:4096 -nodes -keyout /config/key.pem -out /config/cert.pem -sha256 -days 36525 -subj "/CN=${JACKAL_HOST}" -verbose
    fi
}

create_config
create_tls
