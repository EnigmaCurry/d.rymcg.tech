#!/bin/bash
set -e

ytt_template() {
    src=$1; dst=$2;
    [ -e "${src}" ] || (echo "Template not found: ${src}" && exit 1)
    ytt -f ${src} \
        -v node_exporter_enabled=${PROMETHEUS_NODE_EXPORTER_ENABLED} \
        -v cadvisor_enabled=${PROMETHEUS_CADVISOR_ENABLED} \
        -v alertmanager_enabled=${PROMETHEUS_ALERTMANAGER_ENABLED} \
        -v smtp_smarthost=${PROMETHEUS_ALERTMANAGER_SMTP_SMARTHOST} \
        -v smtp_auth_username=${PROMETHEUS_ALERTMANAGER_SMTP_AUTH_USERNAME} \
        -v smtp_auth_password=${PROMETHEUS_ALERTMANAGER_SMTP_AUTH_PASSWORD} \
        -v smtp_from=${PROMETHEUS_ALERTMANAGER_SMTP_FROM} \
        > ${dst}
    success=$?
    echo "[ ! ] GENERATED NEW CONFIG FILE :::  ${dst}"
    return ${success}
}

create_config() {
    rm -rf /etc/prometheus/*
    ytt_template prometheus.yml /etc/prometheus/prometheus.yml
    cat /etc/prometheus/prometheus.yml

    rm -rf /etc/alertmanager/*
    ytt_template alertmanager.yml /etc/alertmanager/alertmanager.yml
    cat /etc/alertmanager/alertmanager.yml
}

create_config
