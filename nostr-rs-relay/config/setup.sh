#!/bin/bash

create_config() {
    cat /template/config.toml | envsubst > /config/config.toml
    echo "[ ! ] GENERATED CONFIG FILE ::: config.toml"
}

create_config
