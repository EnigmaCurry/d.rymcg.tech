#!/bin/bash
set -e

ytt_template() {
    src=$1; dst=$2;
    [ -e "${src}" ] || (echo "Template not found: ${src}" && exit 1)
    ytt -f ${src} \
        -v node_exporter_enabled=${PROMETHEUS_NODE_EXPORTER_ENABLED} \
        -v cadvisor_enabled=${PROMETHEUS_CADVISOR_ENABLED} \
        -v alertmanager_enabled=${PROMETHEUS_ALERTMANAGER_ENABLED} \
        -v smtp_enabled=${PROMETHEUS_ALERTMANAGER_SMTP_ENABLED} \
        -v smtp_smarthost=${PROMETHEUS_ALERTMANAGER_SMTP_SMARTHOST} \
        -v smtp_auth_username=${PROMETHEUS_ALERTMANAGER_SMTP_AUTH_USERNAME} \
        -v smtp_auth_password=${PROMETHEUS_ALERTMANAGER_SMTP_AUTH_PASSWORD} \
        -v smtp_from=${PROMETHEUS_ALERTMANAGER_SMTP_FROM} \
        -v smtp_to=${PROMETHEUS_ALERTMANAGER_SMTP_TO} \
        > ${dst}
    success=$?
    echo "[ ! ] GENERATED NEW CONFIG FILE :::  ${dst}"
    return ${success}
}

create_config() {
    rm -rf /etc/mysql/conf.d/*
    # Currently there are no env vars to template in `onlyoffice.cnf` but we need to copy the file anyway so I'm letting ytt do it. Maybe in the future we'll variablize some of it.
    ytt_template onlyoffice.cnf /etc/mysql/conf.d/onlyoffice.cnf
    #cat /etc/mysql/conf.d/onlyoffice.cnf

    rm -rf /docker-entrypoint-initdb.d/*
    ytt_template setup.sql /docker-entrypoint-initdb.d/setup.sql
    #cat /docker-entrypoint-initdb.d/setup.sql
}

create_config
