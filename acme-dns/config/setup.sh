#!/bin/bash

set -e

create_config() {
    echo "Creating new config from template (config.cfg) ..."
    mkdir -p /config
    rm -f /config/*
    cat /template/config.cfg | envsubst > /config/config.cfg
    echo "[ ! ] GENERATED NEW CONFIG FILE ::: /etc/acme-dns/config.cfg"
}

create_config
