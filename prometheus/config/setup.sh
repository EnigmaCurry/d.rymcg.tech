#!/bin/bash
set -e

ytt_template() {
    src=$1; dst=$2;
    [ -e "${src}" ] || (echo "Template not found: ${src}" && exit 1)
    ytt -f ${src} \
        -v node_exporter_enabled=${PROMETHEUS_NODE_EXPORTER_ENABLED} \
        -v cadvisor_enabled=${PROMETHEUS_CADVISOR_ENABLED} \
        > ${dst}
    success=$?
    echo "[ ! ] GENERATED NEW CONFIG FILE :::  ${dst}"
    return ${success}
}

create_config() {
    rm -rf /etc/prometheus/*
    ytt_template prometheus.yml /etc/prometheus/prometheus.yml
    cat /etc/prometheus/prometheus.yml
}

create_config
