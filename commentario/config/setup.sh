#!/bin/bash

create_config() {
    cat /template/secrets.yaml | envsubst > /config/secrets.yaml
    echo "[ ! ] GENERATED CONFIG FILE ::: secrets.yaml"
}

create_config
