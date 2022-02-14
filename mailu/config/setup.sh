#!/bin/bash

CONFIG_DIR=/overrides

create_config() {
    POSTFIX_TEMPLATE=/template/postfix/postfix.cf
    POSTFIX_CONFIG=${CONFIG_DIR}/postfix/postfix.cf

    echo "No config file found. Generating new config ..."
    mkdir -p ${CONFIG_DIR}
    cat ${POSTFIX_TEMPLATE} | envsubst > ${POSTFIX_CONFIG}
    echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${POSTFIX_CONFIG}"
    [[ $PRINT_CONFIG == true ]] && cat ${POSTFIX_CONFIG}
}

create_config
