#!/bin/bash

CONFIG_DIR=/mosquitto/config
CONFIG=${CONFIG_DIR}/mosquitto.conf
ACL=${CONFIG_DIR}/acl.conf

if [[ -z "${MOSQUITTO_TRAEFIK_HOST}" ]]; then
    echo "MOSQUITTO_TRAEFIK_HOST is empty."
    exit 1
fi

if [[ -z "${MOSQUITTO_DOCKER_CONTEXT}" ]]; then
    echo "MOSQUITTO_DOCKER_CONTEXT is empty."
    exit 1
fi

create_config() {
    echo "Creating new config from template (${TEMPLATE}) ..."
    mkdir -p ${CONFIG_DIR}
    rm -f ${CONFIG}
    cat /template/mosquitto.conf | envsubst '${MOSQUITTO_TRAEFIK_HOST}' > ${CONFIG}
    echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${CONFIG}"
    touch ${CONFIG_DIR}/passwd
    echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${CONFIG}"

    if [[ "${MOSQUITTO_ACL_DISABLE}" == "true" ]]; then
        rm -f ${ACL}
        [[ $PRINT_CONFIG == true ]] && cat ${CONFIG}
    else
        ACL_TEMPLATE=/template/context/${MOSQUITTO_DOCKER_CONTEXT}/acl.conf
        if [[ -f ${ACL_TEMPLATE} ]]; then
            cat ${ACL_TEMPLATE} | envsubst > ${ACL}
        else
            cat /dev/null > ${ACL}
            echo "[ ! ] WARNING: No context ACL file exists. Wrote blank ACL file."
        fi
        chmod 0700 ${ACL}
        chown 1883:1883 ${ACL}
        echo "acl_file /mosquitto/config/acl.conf" >> ${CONFIG}
        echo "[ ! ] GENERATED NEW ACL FILE ::: ${ACL}"
        [[ $PRINT_CONFIG == true ]] && cat ${CONFIG}
        [[ $PRINT_CONFIG == true ]] && echo "-------" && cat ${ACL}
    fi
}

create_config
