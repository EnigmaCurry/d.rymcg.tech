#!/bin/bash

TEMPLATE_DIR=/template
CONFIG_DIR=/data/config

create_config() {
    rm -rf /data/config
    mkdir -p ${CONFIG_DIR}
    for conf in /template/*.{yaml,yml}; do
        [ -e "${conf}" ] || continue
        CONF=${CONFIG_DIR}/$(basename ${conf})
        ytt -f ${conf} \
            -v acme_cert_resolver=${TRAEFIK_ACME_CERT_RESOLVER} \
            -v acme_cert_domains=${TRAEFIK_ACME_CERT_DOMAINS} \
            -v log_level=${TRAEFIK_LOG_LEVEL} \
            -v send_anonymous_usage=${TRAEFIK_SEND_ANONYMOUS_USAGE} \
            -v acme_ca_email=${TRAEFIK_ACME_CA_EMAIL} \
            -v acme_challenge=${TRAEFIK_ACME_CHALLENGE} \
            -v acme_dns_provider=${TRAEFIK_ACME_DNS_PROVIDER} \
            -v access_logs_enabled=${TRAEFIK_ACCESS_LOGS_ENABLED} \
            -v access_logs_path=${TRAEFIK_ACCESS_LOGS_PATH} \
            -v dashboard=${TRAEFIK_DASHBOARD} \
            -v dashboard_auth=${TRAEFIK_DASHBOARD_AUTH} \
            -v file_provider_watch=${TRAEFIK_FILE_PROVIDER_WATCH} \
            > ${CONF}
        echo "[ ! ] GENERATED NEW CONFIG FILE :::  ${CONF}"
        cat ${CONF}
    done
}

create_config
