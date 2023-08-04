#!/bin/bash

CONFIG_DIR=/config
TEMPLATE_DIR=/template

create_config() {
    mkdir -p ${CONFIG_DIR}
	cp ${TEMPLATE_DIR}/* ${CONFIG_DIR}
    echo "[ ! ] COPIED CONFIG FILE(S) TO ${CONFIG_DIR}"
}


create_config
