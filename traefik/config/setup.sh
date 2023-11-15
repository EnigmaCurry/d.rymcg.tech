#!/bin/bash
set -e

CONFIG_DIR=/data/config

ytt_template() {
    src=$1; dst=$2;
    [ -e "${src}" ] || (echo "Template not found: ${src}" && exit 1)
    ytt -f ${src} \
        -v acme_cert_resolver="${TRAEFIK_ACME_CERT_RESOLVER}" \
        -v acme_cert_domains="${TRAEFIK_ACME_CERT_DOMAINS}" \
        -v log_level="${TRAEFIK_LOG_LEVEL}" \
        -v send_anonymous_usage="${TRAEFIK_SEND_ANONYMOUS_USAGE}" \
        -v acme_enabled="${TRAEFIK_ACME_ENABLED}" \
        -v acme_ca_email="${TRAEFIK_ACME_CA_EMAIL}" \
        -v acme_challenge="${TRAEFIK_ACME_CHALLENGE}" \
        -v acme_dns_provider="${TRAEFIK_ACME_DNS_PROVIDER}" \
        -v access_logs_enabled="${TRAEFIK_ACCESS_LOGS_ENABLED}" \
        -v access_logs_path="${TRAEFIK_ACCESS_LOGS_PATH}" \
        -v file_provider_watch="${TRAEFIK_FILE_PROVIDER_WATCH}" \
        -v file_provider="${TRAEFIK_FILE_PROVIDER}" \
        -v docker_provider="${TRAEFIK_DOCKER_PROVIDER}" \
        -v docker_provider_constraints="${TRAEFIK_DOCKER_PROVIDER_CONSTRAINTS}" \
        -v plugins="${TRAEFIK_PLUGINS}" \
        -v plugin_blockpath="${TRAEFIK_PLUGIN_BLOCKPATH}" \
        -v plugin_maxmind_geoip="${TRAEFIK_PLUGIN_MAXMIND_GEOIP}" \
        -v plugin_header_authorization="${TRAEFIK_PLUGIN_HEADER_AUTHORIZATION}" \
        -v plugin_referer="${TRAEFIK_PLUGIN_REFERER}" \
        -v web_entrypoint_enabled="${TRAEFIK_WEB_ENTRYPOINT_ENABLED}" \
        -v web_entrypoint_host="${TRAEFIK_WEB_ENTRYPOINT_HOST}" \
        -v web_entrypoint_port="${TRAEFIK_WEB_ENTRYPOINT_PORT}" \
        -v websecure_entrypoint_enabled="${TRAEFIK_WEBSECURE_ENTRYPOINT_ENABLED}" \
        -v websecure_entrypoint_host="${TRAEFIK_WEBSECURE_ENTRYPOINT_HOST}" \
        -v websecure_entrypoint_port="${TRAEFIK_WEBSECURE_ENTRYPOINT_PORT}" \
        -v web_plain_entrypoint_enabled="${TRAEFIK_WEB_PLAIN_ENTRYPOINT_ENABLED}" \
        -v web_plain_entrypoint_host="${TRAEFIK_WEB_PLAIN_ENTRYPOINT_HOST}" \
        -v web_plain_entrypoint_port="${TRAEFIK_WEB_PLAIN_ENTRYPOINT_PORT}" \
        -v mqtt_entrypoint_enabled="${TRAEFIK_MQTT_ENTRYPOINT_ENABLED}" \
        -v mqtt_entrypoint_host="${TRAEFIK_MQTT_ENTRYPOINT_HOST}" \
        -v mqtt_entrypoint_port="${TRAEFIK_MQTT_ENTRYPOINT_PORT}" \
        -v ssh_entrypoint_enabled="${TRAEFIK_SSH_ENTRYPOINT_ENABLED}" \
        -v ssh_entrypoint_host="${TRAEFIK_SSH_ENTRYPOINT_HOST}" \
        -v ssh_entrypoint_port="${TRAEFIK_SSH_ENTRYPOINT_PORT}" \
        -v dashboard_entrypoint_enabled="${TRAEFIK_DASHBOARD_ENTRYPOINT_ENABLED}" \
        -v dashboard_entrypoint_host="${TRAEFIK_DASHBOARD_ENTRYPOINT_HOST}" \
        -v dashboard_entrypoint_port="${TRAEFIK_DASHBOARD_ENTRYPOINT_PORT}" \
        -v dashboard_auth="${TRAEFIK_DASHBOARD_HTTP_AUTH}" \
        -v vpn_address="${TRAEFIK_VPN_ADDRESS}" \
        -v vpn_enabled="${TRAEFIK_VPN_ENABLED}" \
        -v vpn_subnet="${TRAEFIK_VPN_SUBNET}" \
        -v vpn_entrypoint_host="${TRAEFIK_VPN_ENTRYPOINT_HOST}" \
        -v vpn_entrypoint_port="${TRAEFIK_VPN_ENTRYPOINT_PORT}" \
        -v vpn_proxy_enabled="${TRAEFIK_VPN_PROXY_ENABLED}" \
        -v vpn_client_enabled="${TRAEFIK_VPN_CLIENT_ENABLED}" \
        -v vpn_client_peer_services="${TRAEFIK_VPN_CLIENT_PEER_SERVICES}" \
        -v xmpp_c2s_entrypoint_enabled="${TRAEFIK_XMPP_C2S_ENTRYPOINT_ENABLED}" \
        -v xmpp_c2s_entrypoint_host="${TRAEFIK_XMPP_C2S_ENTRYPOINT_HOST}" \
        -v xmpp_c2s_entrypoint_port="${TRAEFIK_XMPP_C2S_ENTRYPOINT_PORT}" \
        -v xmpp_s2s_entrypoint_enabled="${TRAEFIK_XMPP_S2S_ENTRYPOINT_ENABLED}" \
        -v xmpp_s2s_entrypoint_host="${TRAEFIK_XMPP_S2S_ENTRYPOINT_HOST}" \
        -v xmpp_s2s_entrypoint_port="${TRAEFIK_XMPP_S2S_ENTRYPOINT_PORT}" \
        -v mpd_entrypoint_enabled="${TRAEFIK_MPD_ENTRYPOINT_ENABLED}" \
        -v mpd_entrypoint_host="${TRAEFIK_MPD_ENTRYPOINT_HOST}" \
        -v mpd_entrypoint_port="${TRAEFIK_MPD_ENTRYPOINT_PORT}" \
        -v snapcast_entrypoint_enabled="${TRAEFIK_SNAPCAST_ENTRYPOINT_ENABLED}" \
        -v snapcast_control_entrypoint_enabled="${TRAEFIK_SNAPCAST_CONTROL_ENTRYPOINT_ENABLED}" \
        -v snapcast_entrypoint_host="${TRAEFIK_SNAPCAST_ENTRYPOINT_HOST}" \
        -v snapcast_control_entrypoint_host="${TRAEFIK_SNAPCAST_CONTROL_ENTRYPOINT_HOST}" \
        -v snapcast_entrypoint_port="${TRAEFIK_SNAPCAST_ENTRYPOINT_PORT}" \
        -v snapcast_control_entrypoint_port="${TRAEFIK_SNAPCAST_CONTROL_ENTRYPOINT_PORT}" \
        -v root_domain="${TRAEFIK_ROOT_DOMAIN}" \
        -v vpn_root_domain="${TRAEFIK_VPN_ROOT_DOMAIN}" \
        -v network_mode="${TRAEFIK_NETWORK_MODE}" \
        -v error_handler_403_service="${TRAEFIK_ERROR_HANDLER_403_SERVICE}" \
        -v error_handler_404_service="${TRAEFIK_ERROR_HANDLER_404_SERVICE}" \
        -v error_handler_500_service="${TRAEFIK_ERROR_HANDLER_500_SERVICE}" \
        --data-value-yaml header_authorization_groups="${TRAEFIK_HEADER_AUTHORIZATION_GROUPS}" \
        > ${dst}
    success=$?
    echo "[ ! ] GENERATED NEW CONFIG FILE :::  ${dst}"
    [[ "$TRAEFIK_CONFIG_VERBOSE" == "true" ]] && \
        cat ${dst} && \
        echo "---" \
            || true
    return ${success}
}

create_config() {
    rm -rf ${CONFIG_DIR}
    mkdir -p ${CONFIG_DIR}/dynamic
    ## Traefik static config:
    ytt_template traefik.yml ${CONFIG_DIR}/traefik.yml
    ## Traefik dynamic config:
    for src in $(find . -type f \
                  | grep -v "./traefik.yml" \
                  | grep -E '(.yaml|.yml)$'); do
        dst=${CONFIG_DIR}/dynamic/$(basename ${src})
        set +e
        (ytt_template ${src} ${dst})
        if [[ "$?" != "0" ]]; then
            echo "ERROR: CRITICAL: Dynamic config template failed, therefore removing all the config."
            rm -rf ${CONFIG_DIR}
            exit 1
        fi
        set -e
    done
}

create_config
