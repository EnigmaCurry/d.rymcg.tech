#!/bin/bash
set -e

CONFIG_DIR=/data

ytt_template() {
    src=$1; dst=$2;
    [ -e "${src}" ] || (echo "Template not found: ${src}" && exit 1)
    ytt -f ${src} \
        -v traefik_host=${NTFY_TRAEFIK_HOST} \
        -v auth_default_access=${NTFY_AUTH_DEFAULT_ACCESS} \
        -v attachment_total_size_limit=${NTFY_ATTACHMENT_TOTAL_SIZE_LIMIT} \
        -v attachment_file_size_limit=${NTFY_ATTACHMENT_FILE_SIZE_LIMIT} \
        -v attachment_expiry_duration=${NTFY_ATTACHMENT_EXPIRY_DURATION} \
        -v keepalive_interval=${NTFY_KEEPALIVE_INTERVAL} \
        -v smtp_sender_addr=${NTFY_SMTP_SENDER_ADDR} \
        -v smtp_sender_user=${NTFY_SMTP_SENDER_USER} \
        -v smtp_sender_pass=${NTFY_SMTP_SENDER_PASS} \
        -v smtp_sender_from=${NTFY_SMTP_SENDER_FROM} \
        -v smtp_server_listen=${NTFY_SMTP_SERVER_LISTEN} \
        -v smtp_server_domain=${NTFY_SMTP_SERVER_DOMAIN} \
        -v smtp_server_addr_prefix=${NTFY_SMTP_SERVER_ADDR_PREFIX} \
        > ${dst}
    success=$?
    echo "[ ! ] GENERATED NEW CONFIG FILE :::  ${dst}"
    return ${success}
}

create_config() {
    rm -rf ${CONFIG_DIR}/*
    ytt_template server.yml ${CONFIG_DIR}/server.yml
    cat ${CONFIG_DIR}/server.yml
}

create_config
