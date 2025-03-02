#!/bin/bash
set -e

CONFIG_DIR=/data/config
DYNAMIC_CONFIG_DIR=${CONFIG_DIR}/dynamic
INSTANCE_CONFIG_DIR=${DYNAMIC_CONFIG_DIR}/${DOCKER_CONTEXT:-instance}

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
        -v acme_cert_resolver_production="${TRAEFIK_ACME_CERT_RESOLVER_PRODUCTION}" \
        -v acme_cert_resolver_staging="${TRAEFIK_ACME_CERT_RESOLVER_STAGING}" \
        -v acme_dns_provider="${TRAEFIK_ACME_DNS_PROVIDER}" \
        -v acme_certificates_duration="${TRAEFIK_ACME_CERTIFICATES_DURATION}" \
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
        -v plugin_cert_auth="${TRAEFIK_PLUGIN_CERT_AUTH}" \
        -v plugin_referer="${TRAEFIK_PLUGIN_REFERER}" \
        -v plugin_mtls_header="${TRAEFIK_PLUGIN_MTLS_HEADER}" \
        -v plugin_sablier="${TRAEFIK_PLUGIN_SABLIER}" \
        -v web_entrypoint_enabled="${TRAEFIK_WEB_ENTRYPOINT_ENABLED}" \
        -v web_entrypoint_host="${TRAEFIK_WEB_ENTRYPOINT_HOST}" \
        -v web_entrypoint_port="${TRAEFIK_WEB_ENTRYPOINT_PORT}" \
        -v web_entrypoint_proxy_protocol_trusted_ips="${TRAEFIK_WEB_ENTRYPOINT_PROXY_PROTOCOL_TRUSTED_IPS}" \
        -v websecure_entrypoint_enabled="${TRAEFIK_WEBSECURE_ENTRYPOINT_ENABLED}" \
        -v websecure_entrypoint_host="${TRAEFIK_WEBSECURE_ENTRYPOINT_HOST}" \
        -v websecure_entrypoint_port="${TRAEFIK_WEBSECURE_ENTRYPOINT_PORT}" \
        -v websecure_entrypoint_proxy_protocol_trusted_ips="${TRAEFIK_WEBSECURE_ENTRYPOINT_PROXY_PROTOCOL_TRUSTED_IPS}" \
        -v web_plain_entrypoint_enabled="${TRAEFIK_WEB_PLAIN_ENTRYPOINT_ENABLED}" \
        -v web_plain_entrypoint_host="${TRAEFIK_WEB_PLAIN_ENTRYPOINT_HOST}" \
        -v web_plain_entrypoint_port="${TRAEFIK_WEB_PLAIN_ENTRYPOINT_PORT}" \
        -v web_plain_entrypoint_proxy_protocol_trusted_ips="${TRAEFIK_WEB_PLAIN_ENTRYPOINT_PROXY_PROTOCOL_TRUSTED_IPS}" \
        -v ssh_entrypoint_enabled="${TRAEFIK_SSH_ENTRYPOINT_ENABLED}" \
        -v ssh_entrypoint_host="${TRAEFIK_SSH_ENTRYPOINT_HOST}" \
        -v ssh_entrypoint_port="${TRAEFIK_SSH_ENTRYPOINT_PORT}" \
        -v ssh_entrypoint_proxy_protocol_trusted_ips="${TRAEFIK_SSH_ENTRYPOINT_PROXY_PROTOCOL_TRUSTED_IPS}" \
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
        -v xmpp_c2s_entrypoint_proxy_protocol_trusted_ips="${TRAEFIK_XMPP_C2S_ENTRYPOINT_PROXY_PROTOCOL_TRUSTED_IPS}" \
        -v xmpp_s2s_entrypoint_enabled="${TRAEFIK_XMPP_S2S_ENTRYPOINT_ENABLED}" \
        -v xmpp_s2s_entrypoint_host="${TRAEFIK_XMPP_S2S_ENTRYPOINT_HOST}" \
        -v xmpp_s2s_entrypoint_port="${TRAEFIK_XMPP_S2S_ENTRYPOINT_PORT}" \
        -v xmpp_s2s_entrypoint_proxy_protocol_trusted_ips="${TRAEFIK_XMPP_S2S_ENTRYPOINT_PROXY_PROTOCOL_TRUSTED_IPS}" \
        -v mpd_entrypoint_enabled="${TRAEFIK_MPD_ENTRYPOINT_ENABLED}" \
        -v mpd_entrypoint_host="${TRAEFIK_MPD_ENTRYPOINT_HOST}" \
        -v mpd_entrypoint_port="${TRAEFIK_MPD_ENTRYPOINT_PORT}" \
        -v mpd_entrypoint_proxy_protocol_trusted_ips="${TRAEFIK_MPD_ENTRYPOINT_PROXY_PROTOCOL_TRUSTED_IPS}" \
        -v snapcast_entrypoint_enabled="${TRAEFIK_SNAPCAST_ENTRYPOINT_ENABLED}" \
        -v snapcast_control_entrypoint_enabled="${TRAEFIK_SNAPCAST_CONTROL_ENTRYPOINT_ENABLED}" \
        -v snapcast_entrypoint_host="${TRAEFIK_SNAPCAST_ENTRYPOINT_HOST}" \
        -v snapcast_control_entrypoint_host="${TRAEFIK_SNAPCAST_CONTROL_ENTRYPOINT_HOST}" \
        -v snapcast_entrypoint_port="${TRAEFIK_SNAPCAST_ENTRYPOINT_PORT}" \
        -v snapcast_control_entrypoint_port="${TRAEFIK_SNAPCAST_CONTROL_ENTRYPOINT_PORT}" \
        -v snapcast_entrypoint_proxy_protocol_trusted_ips="${TRAEFIK_SNAPCAST_ENTRYPOINT_PROXY_PROTOCOL_TRUSTED_IPS}" \
        -v snapcast_control_entrypoint_proxy_protocol_trusted_ips="${TRAEFIK_SNAPCAST_CONTROL_ENTRYPOINT_PROXY_PROTOCOL_TRUSTED_IPS}" \
        -v redis_entrypoint_enabled="${TRAEFIK_REDIS_ENTRYPOINT_ENABLED}" \
        -v redis_entrypoint_host="${TRAEFIK_REDIS_ENTRYPOINT_HOST}" \
        -v redis_entrypoint_port="${TRAEFIK_REDIS_ENTRYPOINT_PORT}" \
        -v redis_entrypoint_proxy_protocol_trusted_ips="${TRAEFIK_REDIS_ENTRYPOINT_PROXY_PROTOCOL_TRUSTED_IPS}" \
        -v rtmp_entrypoint_enabled="${TRAEFIK_RTMP_ENTRYPOINT_ENABLED}" \
        -v rtmp_entrypoint_host="${TRAEFIK_RTMP_ENTRYPOINT_HOST}" \
        -v rtmp_entrypoint_port="${TRAEFIK_RTMP_ENTRYPOINT_PORT}" \
        -v rtmp_entrypoint_proxy_protocol_trusted_ips="${TRAEFIK_RTMP_ENTRYPOINT_PROXY_PROTOCOL_TRUSTED_IPS}" \
        -v root_domain="${TRAEFIK_ROOT_DOMAIN}" \
        -v network_mode="${TRAEFIK_NETWORK_MODE}" \
        -v error_handler_403_service="${TRAEFIK_ERROR_HANDLER_403_SERVICE}" \
        -v error_handler_404_service="${TRAEFIK_ERROR_HANDLER_404_SERVICE}" \
        -v error_handler_500_service="${TRAEFIK_ERROR_HANDLER_500_SERVICE}" \
        -v step_ca_enabled="${TRAEFIK_STEP_CA_ENABLED}" \
        -v step_ca_endpoint="${TRAEFIK_STEP_CA_ENDPOINT}" \
        -v step_ca_fingerprint="${TRAEFIK_STEP_CA_FINGERPRINT}" \
        -v layer_7_tls_proxy_enabled="${TRAEFIK_LAYER_7_TLS_PROXY_ENABLED}" \
        -v layer_7_tls_proxy_routes="${TRAEFIK_LAYER_7_TLS_PROXY_ROUTES}" \
        -v layer_4_tcp_udp_proxy_enabled="${TRAEFIK_LAYER_4_TCP_UDP_PROXY_ENABLED}" \
        -v layer_4_tcp_udp_proxy_routes="${TRAEFIK_LAYER_4_TCP_UDP_PROXY_ROUTES}" \
        -v custom_entrypoints="${TRAEFIK_CUSTOM_ENTRYPOINTS}" \
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
    mkdir -p ${DYNAMIC_CONFIG_DIR} ${INSTANCE_CONFIG_DIR}
    ## Traefik static config:
    ytt_template traefik.yml ${CONFIG_DIR}/traefik.yml
    ## Traefik dynamic config:
    for src in $(find . -type f \
                     | grep -v "^./traefik.yml$" \
                     | grep -v "^./context-template" \
                     | grep -E '(.yaml|.yml)$'); do
        dst=${DYNAMIC_CONFIG_DIR}/$(basename ${src})
        set +e
        (ytt_template ${src} ${dst})
        if [[ "$?" != "0" ]]; then
            echo "ERROR: CRITICAL: Dynamic config template failed, therefore removing all the config."
            rm -rf ${CONFIG_DIR}
            exit 1
        fi
        set -e
    done
    ## Templates specific to an indvidual Docker context, by name:
    for src in $(find ./context-template -type f \
                     | grep -E "^./context-template/${DOCKER_CONTEXT}/.*(.yaml|.yml)$"); do
        dst=${INSTANCE_CONFIG_DIR}/$(basename ${src})
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
