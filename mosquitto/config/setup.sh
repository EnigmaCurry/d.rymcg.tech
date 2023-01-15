#!/bin/bash

CONFIG_DIR=/mosquitto/config
CONFIG=${CONFIG_DIR}/mosquitto.conf
ACL=${CONFIG_DIR}/acl.conf

create_config() {
    echo "Creating new config from template (${TEMPLATE}) ..."
    mkdir -p ${CONFIG_DIR}
    rm -f ${CONFIG}
    cat /template/mosquitto.conf | envsubst > ${CONFIG}
    echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${CONFIG}"
    touch ${CONFIG_DIR}/passwd
    echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${CONFIG}"
    cat /template/acl.conf | envsubst > ${ACL}
    echo "[ ! ] GENERATED NEW ACL FILE ::: ${ACL}"
    [[ $PRINT_CONFIG == true ]] && cat ${CONFIG} && echo "------" && cat ${ACL}
}

create_config
