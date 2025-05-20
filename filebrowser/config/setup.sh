#!/bin/bash

create_config() {
    cat /template/config.json | envsubst > /config/config.json
    echo "[ ! ] GENERATED CONFIG FILE ::: config.json"
}

create_config
