#!/bin/bash

create_config() {
    cat /template/icecast.xml | envsubst > /config/icecast.xml
    echo "[ ! ] GENERATED CONFIG FILE ::: icecast.xml"
}

create_config
