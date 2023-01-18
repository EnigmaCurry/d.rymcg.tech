#!/bin/bash

create_config() {
    mkdir -p ${CONFIG_DIR}
    cat /template/mopidy.conf | envsubst > /mopidy_config/mopidy.conf
    echo "[ ! ] GENERATED CONFIG FILE ::: mopidy.conf"
    cat /template/snapserver.conf | envsubst > /snapserver_config/snapserver.conf
    echo "[ ! ] GENERATED CONFIG FILE ::: snapserver.conf"
}

create_config
