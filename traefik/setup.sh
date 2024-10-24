#!/bin/bash

## Configuration menu helper script for Traefik used in d.rymcg.tech Makefiles.
## The only purpose of this script is to help write your .env file,
## it is run on your workstation, and not part of the container itself.

## This script is not to be confused with the ./config directory,
## which is a container runtime helper that configures the Traefik
## config file inside the container's data volume.

BIN=$(dirname ${BASH_SOURCE})/../_scripts
source ${BIN}/funcs.sh
set -e

main_menu() {
    base_config
    while :
    do
        clear
        separator '###' 60 "${DOCKER_CONTEXT}"
        wizard menu --cancel-code=2 --once "Traefik:" \
               "Config = ./setup.sh config" \
               "Install (make install) = make compose-profiles install" \
               "Admin = ./setup.sh admin" \
               "Exit (ESC) = exit 2"
        local EXIT_CODE=$?
        if [[ "${EXIT_CODE}" == "2" ]]; then
            exit 0
        fi
    done
}

base_config() {
    ## Make new .env if it doesn't exist:
    test -f ${ENV_FILE} || cp .env-dist ${ENV_FILE}
    ${BIN}/reconfigure ${ENV_FILE} DOCKER_CONTEXT=${DOCKER_CONTEXT}
}

config() {
    clear
    echo "During first time setup, you must complete the following tasks:"
    echo
    echo " * Create Traefik user."
    echo " * Configure TLS certificates and ACME (optional)."
    echo " * Install traefik."
    echo
    echo "Traefik must be re-installed to apply any changes."
    separator '~~' 60
    wizard menu "Traefik Configuration:" \
           "Traefik user = ./setup.sh traefik_user" \
           "Entrypoints (including dashboard) = ./setup.sh entrypoints" \
           "TLS certificates and authorities = ./setup.sh config_tls" \
           "Middleware (including sentry auth) = ./setup.sh middleware" \
           "Advanced Routing (Layer 7 / Layer 4 / Wireguard) = ./setup.sh routes_menu" \
           "Error page template = ./setup.sh error_pages" \
           "Logging level = ./setup.sh configure_log_level" \
           "Access logs = ./setup.sh configure_access_logs"
}

admin() {
    wizard menu "Traefik Admin:" \
           "Review logs = ./setup.sh logs" \
           "Manage containers = ./setup.sh manage_containers" \
           "Manage wireguard = ./setup.sh manage_wireguard"
}

shell_menu() {
    wizard menu "Enter shell:" \
           "Enter traefik shell = make shell service=traefik" \
           "Enter wireguard server shell = make shell service=wireguard" \
           "Enter wireguard client shell = make shell service=wireguard-client"
}

manage_containers() {
    wizard menu "Traefik Container Management:" \
           "make status - Container status = make status" \
           "make shell - Container shell = ./setup.sh shell_menu" \
           "make uninstall - Uninstall Traefik (keeps data) = make uninstall" \
           "make reinstall - Reinstall Traefik (forced) = make reinstall" \
           "make destroy - Destroy Traefik (uninstall and remove all data) = make destroy"
}

manage_wireguard() {
    wizard menu "Traefik Wireguard:" \
           "make show-wireguard-peers - Show wireguard peer config = make show-wireguard-peers" \
           "make show-wireguard-peers-qr - Show wireguard peer config in QR code format = make show-wireguard-peers-qr"
}


logs() {
    echo
    echo "## Note: This menu can only show log snapshots, it cannot follow live logs."
    echo "## For live logging, try the commands shown in parentheses instead (by hand)."
    wizard menu "Traefik Logs:" \
           "make logs service=traefik - Review Traefik logs (Q to quit) = make logs-out service=traefik | less -r +G" \
           "make logs service=config - Review config logs (Q to quit) = make logs-out service=config | less -r +G" \
           "make logs service=wireguard - Review wireguard logs (Q to quit) = make logs-out service=wireguard | less -r +G" \
           "make logs service=wireguard-client - Review wireguard-client logs (Q to quit) = make logs-out service=wireguard-client | less -r +G" \
           "make logs-access - Review access logs (Q to quit) = make logs-access-out | less -r +G"
}

configure_log_level() {
    local LOG_LEVELS=(error, warn, info, debug)
    local default=1
    local log_level="$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_LOG_LEVEL)"
    case "${log_level}" in
        error) default=0;;
        warn) default=1;;
        info) default=2;;
        debug) default=3;;
    esac
    wizard menu --default ${default} --once "Traefik Log Level:" \
           "error - only show errors. = ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_LOG_LEVEL=error" \
           "warn - show warnings and errors. = ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_LOG_LEVEL=warn" \
           "info - show info, warnings, and errors. = ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_LOG_LEVEL=info" \
           "debug - show debug, info, warnings, and errors. = ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_LOG_LEVEL=debug"
}

configure_access_logs() {
    local access_logs_enabled="$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_ACCESS_LOGS_ENABLED)"
    local enabled_default=no
    if [[ "${access_logs_enabled}" == "true" ]]; then
        enabled_default=yes
    fi
    if ${BIN}/confirm "${enabled_default}" "Do you want to enable the access log" "?"
    then
        ${BIN}/reconfigure ${ENV_FILE} "TRAEFIK_ACCESS_LOGS_ENABLED=true"
    else
        ${BIN}/reconfigure ${ENV_FILE} "TRAEFIK_ACCESS_LOGS_ENABLED=false"
    fi
}

traefik_user() {
    SSH_HOST=$(docker context inspect | jq -r ".[0].Endpoints.docker.Host");
    TRAEFIK_USER=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_USER)
    if [[ "${SSH_HOST}" == unix://* ]]; then
        echo "Not creating the ${TRAEFIK_USER} user because there is no SSH context."
        echo
        echo "You will have to create the ${TRAEFIK_USER} user on the server,"
        echo "and set TRAEFIK_UID and TRAEFIK_GID by hand."
        echo
    else
        SSH_UID=$(ssh ${SSH_HOST} id -u);
        [[ $SSH_UID != "0" ]] && SUDO_PREFIX="sudo" || SUDO_PREFIX="";
        if ssh ${SSH_HOST} id ${TRAEFIK_USER}; then
            echo "Traefik user (${TRAEFIK_USER}) already exists."
            traefik_uid
        else
            if ! ssh ${SSH_HOST} ${SUDO_PREFIX} which adduser; then
                echo
                fault "The Docker host does not have the 'adduser' command installed. You may install it, and retry this command, or simply create the ${TRAEFIK_USER} user manually. (Consult your OS documentation. Note: The user must not be a login account, and you should disable the password and/or account; the purpose of creating the user is only to reserve a unique UID and GID for secure file permissions.)"
            fi

            if ${BIN}/confirm yes "There is no ${TRAEFIK_USER} user created on the Docker host yet. Would you like to create this user automatically? (Note: this can fail if your system does not have the 'adduser' command, so read the directions that it will print out if this fails!)"; then
                local detected_OS=$(ssh ${SSH_HOST} cat /etc/os-release | grep -Po '^ID=\K.*')
                local user_group_arg
                case "$detected_OS" in
                    fedora)
                        user_group_arg="--user-group";;
                    debian|ubuntu)
                        user_group_arg="--group";;
                    *)
                        user_group_arg="--group";;
                esac
                (set -x
                 ssh ${SSH_HOST} ${SUDO_PREFIX} \
                     adduser --shell /usr/sbin/nologin --system \
                     ${user_group_arg} ${TRAEFIK_USER}
                )
                ssh ${SSH_HOST} ${SUDO_PREFIX} gpasswd -a ${TRAEFIK_USER} docker || fault "There was a problem creating the ${TRAEFIK_USER} user. Are you logging in as root?"
                echo "Successfully created the ${TRAEFIK_USER} user!"
                traefik_uid
            fi
        fi
    fi
}

traefik_uid() {
    SSH_HOST=$(docker context inspect | jq -r ".[0].Endpoints.docker.Host");
    if [[ "${SSH_HOST}" == unix://* ]]; then
        ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_UID=1000 TRAEFIK_GID=1000
        ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_DOCKER_GID=$(getent group docker | cut -d ':' -f 3);
    else
        TRAEFIK_UID=$(ssh ${SSH_HOST} id -u ${TRAEFIK_USER})
        TRAEFIK_GID=$(ssh ${SSH_HOST} id -g ${TRAEFIK_USER})
        TRAEFIK_DOCKER_GID=$(ssh ${SSH_HOST} getent group docker | cut -d: -f3)
        ${BIN}/reconfigure ${ENV_FILE} \
              TRAEFIK_UID=${TRAEFIK_UID} \
              TRAEFIK_GID=${TRAEFIK_GID} \
              TRAEFIK_DOCKER_GID=${TRAEFIK_DOCKER_GID}
    fi
}

get_all_entrypoints() {
    sed -n "s/^.*TRAEFIK_\s*\(\S*\)_ENTRYPOINT_ENABLED=.*$/\1/p" .env-dist | tr '[:upper:]' '[:lower:]'
}
get_enabled_entrypoints() {
    sed -n "s/^.*TRAEFIK_\s*\(\S*\)_ENTRYPOINT_ENABLED=true$/\1/p" "${ENV_FILE}" | tr '[:upper:]' '[:lower:]'
}
list_enabled_entrypoints() {
    readarray -t entrypoints < <(get_enabled_entrypoints)
    (
        echo -e "Entrypoint\tListen_address\tListen_port\tProtocol\tUpstream_proxy\tUse_Https"
        echo -e "----------\t--------------\t-----------\t--------\t--------------\t-------"
        (
            for e in "${entrypoints[@]}"; do
                local ENTRYPOINT="$(echo "${e}" | tr '[:lower:]' '[:upper:]')"
                local host="$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_${ENTRYPOINT}_ENTRYPOINT_HOST)"
                local port="$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_${ENTRYPOINT}_ENTRYPOINT_PORT)"
                local proxy_protocol="$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_${ENTRYPOINT}_ENTRYPOINT_PROXY_PROTOCOL_TRUSTED_IPS)"
                echo "${e} ${host} ${port} tcp ${proxy_protocol}"
            done
            list_custom_entrypoints
        ) | sort -u
    ) | column -t
    echo
    echo " * REMINDER: Reconfigure all upstream firewalls accordingly."
    echo "             Restart Traefik to apply changes."
    echo
}

entrypoints() {
    list_enabled_entrypoints
    wizard menu "Traefik entrypoint config" \
           "Show enabled entrypoints = ./setup.sh list_enabled_entrypoints" \
           "Configure stock entrypoints = ./setup.sh config_list_entrypoints" \
           "Configure custom entrypoints = ./setup.sh custom_entrypoints"
}

config_list_entrypoints() {
    readarray -t entrypoint_names < <(get_all_entrypoints)
    declare -A entrypoint_descriptions
    entrypoint_descriptions=(
        [dashboard]="Traefik dashboard (only accessible from 127.0.0.1:8080 and requires HTTP basic auth)"
        [web]="HTTP (unencrypted; used to redirect requests to use HTTPS)"
        [websecure]="HTTPS (TLS encrypted HTTP)"
        [web_plain]="HTTP (unencrypted; specifically NOT redirected to websecure; must use different port than web)"
        [mqtt]="MQTT (mosquitto) pub-sub service"
        [ssh]="SSH (forgejo) git (ssh) entrypoint"
        [xmpp_c2s]="XMPP (ejabberd) client-to-server entrypoint"
        [xmpp_s2s]="XMPP (ejabberd) server-to-server entrypoint"
        [mpd]="Music Player Daemon (mopidy) control entrypoint"
        [redis]="Redis in-memory database entrypoint"
        [rtmp]="Real-Time Messaging Protocol (unencrypted) entrypoint"
        [snapcast]="Snapcast (snapcast) audio entrypoint"
        [snapcast_control]="Snapcast (snapcast) control entrypoint"
    )
    local menu_args=("Select entrypoint to configure:")
    for entrypoint in "${entrypoint_names[@]}"; do
        local description="${entrypoint_descriptions[${entrypoint}]}"
        if [[ -z "${description}" ]]; then
            description="Warning: the documentation has not been updated for this entrypoint"
        fi
        menu_args+=("${entrypoint} : ${description} = ./setup.sh config_entrypoint ${entrypoint}")
    done
    wizard menu "${menu_args[@]}"
}

config_entrypoint() {
    local entrypoint=$1
    check_var entrypoint
    local enabled_default=no
    entrypoint="$(echo "${entrypoint}" | tr '[:upper:]' '[:lower:]')"
    local ENTRYPOINT="$(echo "${entrypoint}" | tr '[:lower:]' '[:upper:]')"
    if [[ "$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_${ENTRYPOINT}_ENTRYPOINT_ENABLED)" == "true" ]]; then
       enabled_default="yes"
    fi
    if ${BIN}/confirm "${enabled_default}" "Do you want to enable the ${entrypoint} entrypoint" "?"; then
        ${BIN}/reconfigure ${ENV_FILE} "TRAEFIK_${ENTRYPOINT}_ENTRYPOINT_ENABLED=true"
        if [[ "${entrypoint}" == "dashboard" ]]; then
            echo
            echo "It's important to protect the dashboard and so a username/password is required."
	        __D_RY_CONFIG_ENTRY=reconfigure_auth ${BIN}/reconfigure_htpasswd ${ENV_FILE} TRAEFIK_DASHBOARD_HTTP_AUTH
            echo "Please note that the dashboard is accessible ONLY from localhost:8080 and requires HTTP basic auth"
            ${BIN}/reconfigure ${ENV_FILE} "TRAEFIK_DASHBOARD_ENTRYPOINT_HOST=127.0.0.1" "TRAEFIK_DASHBOARD_ENTRYPOINT_PORT=8080"
        else
            ${BIN}/reconfigure_ask ${ENV_FILE} "TRAEFIK_${ENTRYPOINT}_ENTRYPOINT_HOST" "Enter the host ip address to listen on (0.0.0.0 to listen on all interfaces)"
            ${BIN}/reconfigure_ask ${ENV_FILE} "TRAEFIK_${ENTRYPOINT}_ENTRYPOINT_PORT" "Enter the host port to listen on"
        fi
        local trusted_ips="$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_${ENTRYPOINT}_ENTRYPOINT_PROXY_PROTOCOL_TRUSTED_IPS)"
        local default_choice=0
        if [[ -n "${trusted_ips}" ]]; then
            default_choice=1
        fi
        echo
        case $(wizard choose --default ${default_choice} --numeric \
                      "Is this entrypoint downstream from another trusted proxy?" \
                      "No, clients dial directly to this server. (Turn off Proxy Protocol)" \
                      "Yes, clients are proxied through a trusted server. (Turn on Proxy Protocol)") in
            0) ${BIN}/reconfigure ${ENV_FILE} "TRAEFIK_${ENTRYPOINT}_ENTRYPOINT_PROXY_PROTOCOL_TRUSTED_IPS=";;
            1) ${BIN}/reconfigure_ask ${ENV_FILE} "TRAEFIK_${ENTRYPOINT}_ENTRYPOINT_PROXY_PROTOCOL_TRUSTED_IPS" "Enter the comma separated list of trusted upstream proxy servers (CIDR)" 10.13.16.1/32;;
        esac
    else
        ${BIN}/reconfigure ${ENV_FILE} "TRAEFIK_${ENTRYPOINT}_ENTRYPOINT_ENABLED=false"
    fi
    echo
}

error_pages() {
    echo
    echo "## See https://github.com/tarampampam/error-pages"
    echo
    local ENABLED=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_ERROR_PAGES_ENABLED)
    if ${BIN}/confirm "${ENABLED}" "Do you want to enable a custom error page template" "?"; then
        ${BIN}/reconfigure ${ENV_FILE} "TRAEFIK_ERROR_PAGES_ENABLED=true"
        TRAEFIK_ERROR_PAGES_TEMPLATE="$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_ERROR_PAGES_TEMPLATE)"
        ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_ERROR_PAGES_TEMPLATE="$(${BIN}/script-wizard choose --default ${TRAEFIK_ERROR_PAGES_TEMPLATE:-l7-light}  'Select an error page theme (https://github.com/tarampampam/error-pages#-templates)' ghost l7-light l7-dark shuffle noise hacker-terminal cats lost-in-space app-down connection matrix orient)"
    else
        ${BIN}/reconfigure ${ENV_FILE} "TRAEFIK_ERROR_PAGES_ENABLED=false"
    fi
}

if [[ "$#" -lt 1 ]]; then
    fault "Wrong number of arguments. Try running \`make config\` instead."
fi

middleware() {
    wizard menu "Traefik middleware config:" \
           "MaxMind geoIP locator = ./setup.sh maxmind_geoip" \
           "OAuth2 sentry authorization (make sentry) = make sentry"
}

maxmind_geoip() {
    if ${BIN}/confirm $([[ $(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_PLUGIN_MAXMIND_GEOIP) == "true" ]] && echo "yes" || echo "no") "Do you want to enable the MaxMind GeoIP client locator plugin" "?"; then
        ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_PLUGIN_MAXMIND_GEOIP=true
    else
        ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_PLUGIN_MAXMIND_GEOIP=false
    fi
    if [[ $(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_PLUGIN_MAXMIND_GEOIP) == "true" ]]; then
        echo "You may create a free MaxMind account: https://www.maxmind.com/en/geolite2/signup"
        echo "Login to your MaxMind account and create a License Key."
        echo ""
        ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_GEOIPUPDATE_ACCOUNT_ID "Enter your MaxMind account ID"
        ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_GEOIPUPDATE_LICENSE_KEY "Enter your MaxMind license key"
        ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_GEOIPUPDATE_EDITION_IDS "Enter the GeoIP database IDs you wish to install" "GeoLite2-ASN GeoLite2-City GeoLite2-Country"
    fi
}

layer_7_tls_proxy_get_routes() {
    local ENABLED=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_LAYER_7_TLS_PROXY_ENABLED)
    local ROUTES=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_LAYER_7_TLS_PROXY_ROUTES)
    if [ "${ENABLED}" != "true" ] || [ -z "${ROUTES}" ]; then
        echo "## No layer 7 routes defined." >/dev/stderr
        return
    fi
    echo "## Configured Layer 7 Routes:" >/dev/stderr
    (echo "${ROUTES}" | tr ',' '\n' | sed 's/:/\t/g' | sort -u) | column -t
}

layer_7_tls_proxy_list_routes() {
    local ROUTES="$(layer_7_tls_proxy_get_routes)"
    if [[ -z "${ROUTES}" ]]; then
        return
    fi
    ( 
      echo -e "Entrypoint\tDestination_address\tDestination_port\tProxy_protocol"
      echo -e "----------\t-------------------\t----------------\t--------------"
      echo "${ROUTES}" ) \
        | column -t
}

layer_7_tls_proxy_add_ingress_route() {
    echo "Adding a new layer 7 TLS proxy route - "
    echo
    echo " * Make sure to set your route's DNS record to point to this Traefik instance."
    echo " * The public port must be 443, but any destination port can be used."
    echo " * Make sure your backend server provides its own passthrough certificate."
    echo
    while
        ask_no_blank "Enter the public domain (SNI) for the route:" ROUTE_DOMAIN www.${ROOT_DOMAIN}
        if layer_7_tls_proxy_get_routes 2>/dev/null | grep "^${ROUTE_DOMAIN}\W" >/dev/null 2>&1; then
            echo
            echo "## That domain is already used in an existing ingress route:"
            layer_7_tls_proxy_get_routes 2>/dev/null | grep "^${ROUTE_DOMAIN}\W"
            echo
            continue
        fi
        false
    do true; done
    echo
    while
        ask_no_blank "Enter the destination IP address to forward to:" ROUTE_IP_ADDRESS 10.13.16.2
        if ! validate_ip_address ${ROUTE_IP_ADDRESS}; then
            echo "Invalid IP address."
            continue
        fi
        false
    do true; done
    echo
    while
        ask_no_blank "Enter the destination TCP port to forward to:" ROUTE_PORT 443
        if ! [[ ${ROUTE_PORT} =~ ^[0-9]+$ ]] ; then
            echo "Port is invalid."
            continue
        fi
        false
    do true; done
    local ROUTE_PROXY_PROTOCOL=0
    echo "##"
    echo "## See https://www.haproxy.org/download/2.0/doc/proxy-protocol.txt"
    echo
    if confirm no "Do you want to enable Proxy Protocol for this route" "?"; then
        ROUTE_PROXY_PROTOCOL=2
    fi

    local ROUTES=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_LAYER_7_TLS_PROXY_ROUTES)
    if [[ -n "${ROUTES}" ]]; then
        ROUTES="${ROUTES},"
    fi
    ROUTES="${ROUTES}${ROUTE_DOMAIN}:${ROUTE_IP_ADDRESS}:${ROUTE_PORT}:${ROUTE_PROXY_PROTOCOL}"
    ${BIN}/reconfigure ${ENV_FILE} "TRAEFIK_LAYER_7_TLS_PROXY_ROUTES=${ROUTES}"
}

layer_7_tls_proxy_manage_ingress_routes() {
    mapfile -t routes < <( layer_7_tls_proxy_get_routes )
    if [[ "${#routes[@]}" == 0 ]]; then
        return
    fi
    mapfile -t to_delete < <(wizard select "Select routes to DELETE:" "${routes[@]}")
    if [[ "${#to_delete[@]}" == 0 ]]; then
        return
    fi
    debug_array to_delete
    echo
    if confirm no "Do you really want to delete these routes" "?"; then
        local ROUTES_TMP=$(mktemp)
        local TO_DELETE_TMP=$(mktemp)
        local ROUTES_EDIT=$(mktemp)
        (IFS=$'\n'; echo "${routes[*]}") | sort -u > "${ROUTES_TMP}"
        (IFS=$'\n'; echo "${to_delete[*]}") | sort -u > "${TO_DELETE_TMP}"
        local ROUTES=$(comm -23 "${ROUTES_TMP}" "${TO_DELETE_TMP}" | sed 's/[ \t]\+/:/g' | tr '\n' ',' | sed 's/,\{1,\}/,/g' | sed 's/^,*//;s/,*$//')
        ${BIN}/reconfigure ${ENV_FILE} "TRAEFIK_LAYER_7_TLS_PROXY_ROUTES=${ROUTES}"
    fi
    echo
    layer_7_tls_proxy_list_routes
}

layer_7_tls_proxy_disable() {
    local ENABLED=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_LAYER_7_TLS_PROXY_ENABLED)
    if [[ "${ENABLED}" == "true" ]]; then
        confirm yes "Do you want to disable the layer 7 TLS proxy" "?" && \
            ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_LAYER_7_TLS_PROXY_ENABLED=false && \
            echo "## Layer 7 TLS Proxy is DISABLED." && exit 2
    else
        echo "## Layer 7 TLS Proxy is DISABLED." && exit 2
    fi
}

layer_7_tls_proxy() {
    echo "## Layer 7 TLS Proxy can forward TLS connections to direct IP addresses."
    echo
    local ENABLED=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_LAYER_7_TLS_PROXY_ENABLED)
    if [[ "${ENABLED}" == "true" ]]; then
        while :
        do
            echo
            echo "## Layer 7 TLS Proxy is ENABLED."
            layer_7_tls_proxy_list_routes
            wizard menu --once --cancel-code 2 "Layer 7 TLS Proxy:" \
                   "List layer 7 ingress routes = ./setup.sh layer_7_tls_proxy_list_routes" \
                   "Add new layer 7 ingress route = ./setup.sh layer_7_tls_proxy_add_ingress_route" \
                   "Remove layer 7 ingress routes = ./setup.sh layer_7_tls_proxy_manage_ingress_routes" \
                   "Disable layer 7 TLS Proxy = ./setup.sh layer_7_tls_proxy_disable"
            local EXIT_CODE=$?
            case "$EXIT_CODE" in
                0) continue;;
                2) return 0;;
                *) return 1;;
            esac
        done
    else
        echo "## Layer 7 TLS Proxy is DISABLED."
        confirm no "Do you want to enable the layer 7 TLS proxy" "?" && \
            ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_LAYER_7_TLS_PROXY_ENABLED=true && \
            layer_7_tls_proxy || true
    fi
}

custom_entrypoints() {
    echo "## Custom Entrypoints can add new TCP or UDP port bindings."
    echo
    wizard menu "Custom Entrypoints:" \
           "List custom entrypoints = ./setup.sh list_custom_entrypoints" \
           "Add new custom entrypoint = ./setup.sh add_custom_entrypoint" \
           "Remove custom entrypoints = ./setup.sh manage_custom_entrypoints"
}

layer_4_tcp_udp_proxy() {
    echo "## Layer 4 TCP/UDP Proxy can forward traffic to other machines."
    echo
    local ENABLED=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_LAYER_4_TCP_UDP_PROXY_ENABLED)
    if [[ "${ENABLED}" == "true" ]]; then
        while :
        do
            echo
            echo "## Layer 4 TCP/UDP Proxy is ENABLED."
            layer_4_tcp_udp_list_routes
            wizard menu --cancel-code 2 "Layer 4 TCP/UDP Proxy:" \
                   "List layer 4 ingress routes = ./setup.sh layer_4_tcp_udp_list_routes" \
                   "Add new layer 4 ingress route = ./setup.sh layer_4_tcp_udp_add_ingress_route" \
                   "Remove layer 4 ingress routes = ./setup.sh layer_4_tcp_udp_proxy_manage_ingress_routes" \
                   "Disable layer 4 TCP/UDP Proxy = ./setup.sh layer_4_tcp_udp_proxy_disable"
            local EXIT_CODE=$?
            case "$EXIT_CODE" in
                0) continue;;
                2) return 0;;
                *) return 1;;
            esac
        done
    else
        echo "## Layer 4 TCP/UDP Proxy is DISABLED."
        confirm no "Do you want to enable the layer 4 TCP/UDP proxy" "?" && \
            ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_LAYER_4_TCP_UDP_PROXY_ENABLED=true && \
            layer_4_tcp_udp_proxy || true
    fi
}

layer_4_tcp_udp_proxy_disable() {
    local ENABLED=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_LAYER_4_TCP_UDP_PROXY_ENABLED)
    if [[ "${ENABLED}" == "true" ]]; then
        confirm yes "Do you want to disable the layer 4 TLS proxy" "?" && \
            ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_LAYER_4_TCP_UDP_PROXY_ENABLED=false && \
            echo "## Layer 4 TLS Proxy is DISABLED." && exit 2
    else
        echo "## Layer 4 TLS Proxy is DISABLED." && exit 2
    fi
}


layer_4_tcp_udp_list_routes() {
    local ROUTES="$(layer_4_tcp_udp_get_routes)"
    if [[ -z "${ROUTES}" ]]; then
        return
    fi
    ( echo "## Configured Layer 4 Routes:" >/dev/stderr
      echo -e "Entrypoint\tDestination_address\tDestination_port\tProxy_protocol"
      echo -e "----------\t-------------------\t----------------\t--------------"
      echo "${ROUTES}" ) \
        | column -t
}

layer_4_tcp_udp_get_routes() {
    local ENABLED=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_LAYER_4_TCP_UDP_PROXY_ENABLED)
    local ROUTES=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_LAYER_4_TCP_UDP_PROXY_ROUTES)
    if [ "${ENABLED}" != "true" ] || [ -z "${ROUTES}" ]; then
        echo "## No layer 4 routes defined." >/dev/stderr
        return
    fi
    echo "${ROUTES}" | tr ',' '\n' | sed 's/:/\t/g' | sort -u
}

layer_4_tcp_udp_add_ingress_route() {
    echo "Adding a new layer 4 TCP/UDP proxy route - "
    echo
    echo " * Each layer 4 route requires a unique entrypoint (ie. port)."
    echo " * Before you can create a route, you must create a 'custom entrypoint'."
    echo " * Make sure to set your route's DNS record to point to this Traefik instance."
    echo " * Don't use this for TLS (or HTTPS) - prefer layer 7 proxy instead."
    echo
    local ROUTES=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_LAYER_4_TCP_UDP_PROXY_ROUTES)
    readarray -t entrypoints < <(get_enabled_entrypoints | grep -v '^web$' | grep -v '^websecure$' | grep -v '^dashboard$')
    readarray -t -O"${#entrypoints[@]}" entrypoints < <(get_custom_entrypoints)
    readarray -t used_entrypoints < <(echo ${ROUTES} | tr ',' '\n' | cut -d: -f1 | grep -v "^$")
    readarray -t unused_entrypoints < <(comm -3 <(printf "%s\n" "${entrypoints[@]}" | sort | grep -v "^$") <(printf "%s\n" "${used_entrypoints[@]}" | sort | grep -v "^$") | sort -n)

    # debug_array entrypoints
    # debug_array used_entrypoints
    # debug_array unused_entrypoints
    if [[ "${#unused_entrypoints[@]}" == 0 ]]; then
        echo
        echo "## Error: No unused entrypoints exist."
        echo "## You need to create a new (stock or custom) entrypoint first."
        echo
        return
    fi
    local ENTRYPOINT=$(wizard choose "Entrypoint" "${unused_entrypoints[@]}")
    while
        ask_no_blank "Enter the destination IP address to forward to:" ROUTE_IP_ADDRESS 10.13.16.2
        if ! validate_ip_address ${ROUTE_IP_ADDRESS}; then
            echo "Invalid IP address."
            continue
        fi
        false
    do true; done
    echo
    local DEFAULT_PORT=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_${ENTRYPOINT^^}_ENTRYPOINT_PORT || (${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_CUSTOM_ENTRYPOINTS | tr ',' '\n' | grep "^${ENTRYPOINT}:" | cut -d: -f3))
    while
        ask_no_blank "Enter the destination TCP port to forward to:" ROUTE_PORT "${DEFAULT_PORT}"
        if ! [[ ${ROUTE_PORT} =~ ^[0-9]+$ ]] ; then
            echo "Port is invalid."
            continue
        fi
        false
    do true; done
    echo
    local ROUTE_PROXY_PROTOCOL=0
    echo "##"
    echo "## See https://www.haproxy.org/download/2.0/doc/proxy-protocol.txt"
    echo
    if confirm no "Do you want to enable Proxy Protocol for this route" "?"; then
        ROUTE_PROXY_PROTOCOL=2
    fi
    if [[ -n "${ROUTES}" ]]; then
        ROUTES="${ROUTES},"
    fi
    ROUTES="${ROUTES}${ENTRYPOINT}:${ROUTE_IP_ADDRESS}:${ROUTE_PORT}:${ROUTE_PROXY_PROTOCOL}"
    ${BIN}/reconfigure ${ENV_FILE} "TRAEFIK_LAYER_4_TCP_UDP_PROXY_ROUTES=${ROUTES}"
    layer_4_tcp_udp_list_routes    
}

layer_4_tcp_udp_proxy_manage_ingress_routes() {
    mapfile -t routes < <( layer_4_tcp_udp_get_routes )
    debug_array routes
    if [[ "${#routes[@]}" == 0 ]]; then
        return
    fi
    mapfile -t to_delete < <(wizard select "Select routes to DELETE:" "${routes[@]}")
    if [[ "${#to_delete[@]}" == 0 ]]; then
        return
    fi
    debug_array to_delete
    echo
    if confirm no "Do you really want to delete these routes" "?"; then
        local ROUTES_TMP=$(mktemp)
        local TO_DELETE_TMP=$(mktemp)
        local ROUTES_EDIT=$(mktemp)
        (IFS=$'\n'; echo "${routes[*]}") | sort -u > "${ROUTES_TMP}"
        (IFS=$'\n'; echo "${to_delete[*]}") | sort -u > "${TO_DELETE_TMP}"
        local ROUTES=$(comm -23 "${ROUTES_TMP}" "${TO_DELETE_TMP}" | sed 's/[ \t]\+/:/g' | tr '\n' ',' | sed 's/,\{1,\}/,/g' | sed 's/^,*//;s/,*$//')
        ${BIN}/reconfigure ${ENV_FILE} "TRAEFIK_LAYER_4_TCP_UDP_PROXY_ROUTES=${ROUTES}"
    fi
    echo
    layer_4_tcp_udp_list_routes
}

get_custom_entrypoints() {
    local ENTRYPOINTS=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_CUSTOM_ENTRYPOINTS)
    (echo "${ENTRYPOINTS}" | tr ',' '\n' | cut -d: -f1 | sort -u)
}

list_custom_entrypoints() {
    local ENTRYPOINTS=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_CUSTOM_ENTRYPOINTS)
    if [ -z "${ENTRYPOINTS}" ]; then
        #echo "## No custom entrypoints defined." >/dev/stderr
        return
    fi
    (echo "${ENTRYPOINTS}" | tr ',' '\n' | sed 's/::/:-:/g' | sed 's/:/\t/g' | sort -u) | column -t
}

manage_custom_entrypoints() {
    local CUSTOM_ENTRYPOINTS=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_CUSTOM_ENTRYPOINTS)
    mapfile -t entrypoints < <( echo "${CUSTOM_ENTRYPOINTS}" | tr ',' '\n' )
    if [ -z "${CUSTOM_ENTRYPOINTS}" ] || [[ "${#entrypoints[@]}" == 0 ]]; then
        #echo "## No custom entrypoints defined." >/dev/stderr
        return
    fi
    mapfile -t to_delete < <(wizard select "Select entrypoints to DELETE:" "${entrypoints[@]}")
    if [[ "${#to_delete[@]}" == 0 ]]; then
        return
    fi
    debug_array to_delete
    echo
    if confirm no "Do you really want to delete these entrypoints" "?"; then
        local ENTRYPOINTS_TMP=$(mktemp)
        local TO_DELETE_TMP=$(mktemp)
        local ENTRYPOINTS_EDIT=$(mktemp)
        (IFS=$'\n'; echo "${entrypoints[*]}") | sort -u > "${ENTRYPOINTS_TMP}"
        (IFS=$'\n'; echo "${to_delete[*]}") | sort -u > "${TO_DELETE_TMP}"
        local ENTRYPOINTS=$(comm -23 "${ENTRYPOINTS_TMP}" "${TO_DELETE_TMP}" | tr '\t' ':' | tr '\n' ',' | sed 's/,\{1,\}/,/g' | sed 's/^,*//;s/,*$//')
        ${BIN}/reconfigure ${ENV_FILE} "TRAEFIK_CUSTOM_ENTRYPOINTS=${ENTRYPOINTS}"
    fi
    echo
    list_custom_entrypoints
}


add_custom_entrypoint() {
    echo "Adding a custom TCP/UDP entrypoint - "
    echo
    echo " * Make sure to enable the port in all upstream firewalls."
    echo " * Make sure each entrypoint has a unique lower-case one-word name."
    echo
    local CUSTOM_ENTRYPOINTS=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_CUSTOM_ENTRYPOINTS)
    ENTRYPOINT=""
    while
        ask_no_blank "Enter the new entrypoint name:" ENTRYPOINT "${ENTRYPOINT}"
        if echo ${ENTRYPOINT} | grep -vP "^[a-z][_a-z0-9]*$" >/dev/null 2>&1; then
            echo
            echo "## That name is invalid. Try again:"
            continue
        fi
        if (get_all_entrypoints | grep "^${ENTRYPOINT}$" >/dev/null 2>&1) || \
           (echo ",${CUSTOM_ENTRYPOINTS}" | grep ",${ENTRYPOINT}:" >/dev/null 2>&1); then
            echo
            echo "## That entrypoint name is already taken."
            echo
            continue
        fi
        false
    do true; done
    echo
    while
        ask_no_blank "Enter the entrypoint listen address:" ENTRYPOINT_IP_ADDRESS 0.0.0.0
        if ! validate_ip_address ${ENTRYPOINT_IP_ADDRESS}; then
            echo "Invalid IP address."
            continue
        fi
        false
    do true; done
    echo
    while
        ask_no_blank "Enter the entrypoint port:" ENTRYPOINT_PORT
        if ! [[ ${ENTRYPOINT_PORT} =~ ^[0-9]+$ ]] ; then
            echo "Port is invalid."
            continue
        fi
        false
    do true; done
    echo
    while
        ask_no_blank "Enter the protocol (tcp or udp):" PROTOCOL tcp
        if ! [[ ${PROTOCOL} =~ ^(tcp|udp)$ ]] ; then
            echo "Protocol must be tcp or udp."
            continue
        fi
        false
    do true; done
    local TRUSTED_NETS=
    case $(wizard choose --numeric \
                  "Is this entrypoint downstream from another trusted proxy?" \
                  "No, clients dial directly to this server. (Turn off Proxy Protocol)" \
                  "Yes, clients are proxied through another trusted proxy. (Turn on Proxoy Protocol)") in
        0) TRUSTED_NETS=;;
        1) TRUSTED_NETS=$(ask_echo "Enter the comma separated list of trusted upstream proxy servers (CIDR)" 10.13.16.1/32);;
    esac
    USE_HTTPS=$(choose "Does this entrypoint use HTTPS?" "true" "false")
    if [[ -n "${CUSTOM_ENTRYPOINTS}" ]]; then
        CUSTOM_ENTRYPOINTS="${CUSTOM_ENTRYPOINTS},"
    fi
    CUSTOM_ENTRYPOINTS="${CUSTOM_ENTRYPOINTS}${ENTRYPOINT}:${ENTRYPOINT_IP_ADDRESS}:${ENTRYPOINT_PORT}:${PROTOCOL}:${TRUSTED_NETS}:${USE_HTTPS}"
    ${BIN}/reconfigure ${ENV_FILE} "TRAEFIK_CUSTOM_ENTRYPOINTS=${CUSTOM_ENTRYPOINTS}"
}

routes_menu() {
    echo
    wizard menu "Traefik routes" \
           "Configure layer 7 TLS proxy = ./setup.sh layer_7_tls_proxy || true" \
           "Configure layer 4 TCP/UDP proxy = ./setup.sh layer_4_tcp_udp_proxy || true" \
           "Configure wireguard VPN = ./setup.sh wireguard"
}


config_tls() {
    wizard menu "Traefik TLS config:" \
           "Configure certificate authorities (CA) = make config-ca" \
           "Configure ACME (Let's Encrypt or Step-CA) = make config-acme" \
           "Configure TLS certificates (make certs) = make certs"
}

wireguard() {
    set_all_entrypoint_host() {
        # Set all entrypoint host vars, except for the traefik dashboard:
        HOST=$1; shift; check_var HOST;
        readarray -t entrypoints < <(get_all_entrypoints | grep -v "^dashboard$")
        for var in "${entrypoints[@]}"; do
            ${BIN}/reconfigure ${ENV_FILE} "TRAEFIK_${var^^}_ENTRYPOINT_HOST=${HOST}"
        done        
    }
    set_public_no_wireguard() {
        ${BIN}/reconfigure ${ENV_FILE} \
              TRAEFIK_VPN_ENABLED=false \
              TRAEFIK_VPN_CLIENT_ENABLED=false \
              TRAEFIK_DASHBOARD_ENTRYPOINT_HOST=127.0.0.1 \
              TRAEFIK_NETWORK_MODE=host
        make --no-print-directory compose-profiles
        set_all_entrypoint_host 0.0.0.0
    }
    set_wireguard_server() {
        ${BIN}/reconfigure ${ENV_FILE} \
              TRAEFIK_VPN_ENABLED=true \
              TRAEFIK_VPN_CLIENT_ENABLED=false \
              TRAEFIK_DASHBOARD_ENTRYPOINT_HOST=127.0.0.1 \
              TRAEFIK_NETWORK_MODE=service:wireguard
        echo
        make --no-print-directory compose-profiles
        local DEFAULT_CHOICE=0
        if [[ "$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_WEBSECURE_ENTRYPOINT_HOST)" != "0.0.0.0" ]]; then
            DEFAULT_CHOICE=1
        fi
        case $(wizard choose --default ${DEFAULT_CHOICE} --numeric \
               "Should Traefik bind itself exclusively to the VPN interface?" \
               "No, Traefik should work on all interfaces (including the VPN)." \
               "Yes, Traefik should only listen on the VPN interface.") in
            0)
                set_all_entrypoint_host 0.0.0.0
                ;;
            1)
                set_all_entrypoint_host $(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ADDRESS)
                ;;
            *) return;;
        esac
        echo
        ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_HOST "Enter the public Traefik VPN hostname" ${ROOT_DOMAIN}
 	    ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_SUBNET "Enter the Traefik VPN private subnet (no mask)"
 	    ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_ADDRESS "Enter the Traefik VPN private IP address" 10.13.16.1
 	    ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_PORT "Enter the Traefik VPN TCP port number"
        local VPN_PEERS=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_PEERS)
        while
            ask_no_blank "Enter the Traefik VPN peers list" VPN_PEERS "${VPN_PEERS}"
            if ! [[ "${VPN_PEERS}" =~ ^[a-zA-Z0-9,]+$ ]]; then
                echo 
                echo "Invalid peers list: each peer name must be alphanumeric, no spaces, dashes, underscores etc."
                echo
                continue
            fi
            false
        do true; done
        ${BIN}/reconfigure ${ENV_FILE} \
              TRAEFIK_VPN_PEERS="${VPN_PEERS}" \
              TRAEFIK_VPN_ALLOWED_IPS=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_SUBNET)/24
    }
    set_wireguard_client() {
        ${BIN}/reconfigure ${ENV_FILE} \
              TRAEFIK_VPN_ENABLED=false \
              TRAEFIK_VPN_CLIENT_ENABLED=true \
              TRAEFIK_DASHBOARD_ENTRYPOINT_HOST=127.0.0.1 \
              TRAEFIK_NETWORK_MODE=service:wireguard-client
        echo
        make --no-print-directory compose-profiles
        local DEFAULT_CHOICE=0
        if [[ "$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_WEBSECURE_ENTRYPOINT_HOST)" != "0.0.0.0" ]]; then
            DEFAULT_CHOICE=1
        fi
        case $(wizard choose --default ${DEFAULT_CHOICE} --numeric \
               "Should Traefik bind itself exclusively to the VPN interface?" \
               "No, Traefik should work on all host interfaces (including the VPN)." \
               "Yes, Traefik should only listen on the VPN interface.") in
            0)
                set_all_entrypoint_host 0.0.0.0
                ;;
            1)
                set_all_entrypoint_host $(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_CLIENT_INTERFACE_ADDRESS)
                ;;
            *) return;;
        esac
 	    echo "Scan the QR code for the client credentials printed in the wireguard server's log. Copy the details from the decoded QR code (The first line should be: [Interface]):"
 	    ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_CLIENT_INTERFACE_ADDRESS "Enter the wireguard client Interface Address"
 	    ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_CLIENT_INTERFACE_PRIVATE_KEY "Enter the wireguard PrivateKey (ends with =)"
 	    ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_CLIENT_INTERFACE_LISTEN_PORT "Enter the wireguard listen port" 51820
 	    ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_CLIENT_PEER_PUBLIC_KEY "Enter the Peer PublicKey (ends with =)"
 	    ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_CLIENT_PEER_PRESHARED_KEY "Enter the Peer PresharedKey (ends with =)"
 	    ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_CLIENT_PEER_ENDPOINT "Enter the Peer Endpoint (host:port)"
 	    ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_CLIENT_PEER_ALLOWED_IPS "Enter the Peer AllowedIPs"
    }
    local VPN_ENABLED=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ENABLED)
    local VPN_CLIENT_ENABLED=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_CLIENT_ENABLED)
    local DEFAULT_CHOICE=0
    if [[ "${VPN_ENABLED}" == "true" ]]; then
        DEFAULT_CHOICE=1
    elif [[ "${VPN_CLIENT_ENABLED}" == "true" ]]; then
        DEFAULT_CHOICE=2
    fi
    case $(wizard choose --default ${DEFAULT_CHOICE} --numeric \
           "Should this Traefik instance connect to a wireguard VPN?" \
           "No, Traefik should use the host network directly." \
           "Yes, and this Traefik instance should start the wireguard server." \
           "Yes, but this Traefik instance needs credentials to connect to an outside VPN.") in
        0) set_public_no_wireguard;;
        1) set_wireguard_server;;
        2) set_wireguard_client;;
        *) return;;
    esac
}

echo
check_var ENV_FILE
check_var DOCKER_CONTEXT

$@
