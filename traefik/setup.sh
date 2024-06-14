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
    separator '###' 60 "Traefik Config"
    echo "During first time setup, you must complete the following tasks:"
    echo
    echo " * Create traefik system user on Docker host"
    echo " * Configure ACME"
    echo " * Configure TLS certificates"
    echo " * Install traefik"
    echo

    separator '~~' 60

    wizard menu "Traefik config main menu:" \
           "Create system user on Docker host = ./setup.sh traefik_user" \
           "Configure entrypoints (including dashboard) = ./setup.sh entrypoints" \
           "Configure Certificate Authorities (CA) = make config-ca" \
           "Configure ACME (Let's Encrypt or Step-CA) = make config-acme" \
           "Configure TLS certificates and domains (make certs) = make certs" \
           "Configure middleware (including auth) = ./setup.sh middleware" \
           "Configure error page template = ./setup.sh error_pages" \
           "Configure wireguard VPN = ./setup.sh wireguard" \
           "Configure layer 7 TLS Proxy = ./setup.sh layer_7_tls_proxy" \
           "Reinstall Traefik (make install) = make install" \
           "Exit = exit 2"
}

base_config() {
    ## Make new .env if it doesn't exist:
    test -f ${ENV_FILE} || cp .env-dist ${ENV_FILE}
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
                ssh ${SSH_HOST} ${SUDO_PREFIX} \
                    adduser --shell /usr/sbin/nologin --system ${TRAEFIK_USER} \
                    --group && \
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
    readarray -t entrypoints < <(sed -n "s/^.*TRAEFIK_\s*\(\S*\)_ENTRYPOINT_ENABLED=true$/\1/p" "${ENV_FILE}" | tr '[:upper:]' '[:lower:]')
    (for e in "${entrypoints[@]}"; do
        local ENTRYPOINT="$(echo "${e}" | tr '[:lower:]' '[:upper:]')"
        local host="$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_${ENTRYPOINT}_ENTRYPOINT_HOST)"
        local port="$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_${ENTRYPOINT}_ENTRYPOINT_PORT)"
        echo "${e} - ${host}:${port}"
    done) | column -t -s "-"
}

entrypoints() {
    wizard menu "Traefik entrypoint config" \
           "Show enabled entrypoints = ./setup.sh get_enabled_entrypoints" \
           "Configure available entrypoints = ./setup.sh config_list_entrypoints"
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
        [ssh]="SSH (gitea) git (ssh) endpoint"
        [xmpp_c2s]="XMPP (ejabberd) client-to-server endpoint"
        [xmpp_s2s]="XMPP (ejabberd) server-to-server endpoint"
        [mpd]="Music Player Daemon (mopidy) control endpoint"
        [redis]="Redis in-memory database endpoint"
        [snapcast]="Snapcast (snapcast) audio endpoint"
        [snapcast_control]="Snapcast (snapcast) control endpoint"
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
    if ${BIN}/confirm "${enabled_default}" "Do you want to enable the ${entrypoint} entrypoint?"; then
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
    else
        ${BIN}/reconfigure ${ENV_FILE} "TRAEFIK_${ENTRYPOINT}_ENTRYPOINT_ENABLED=false"
    fi
}

error_pages() {
    TRAEFIK_ERROR_PAGES_TEMPLATE="$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_ERROR_PAGES_TEMPLATE)"
    ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_ERROR_PAGES_TEMPLATE="$(${BIN}/script-wizard choose --default ${TRAEFIK_ERROR_PAGES_TEMPLATE:-l7-light}  'Select an error page theme (https://github.com/tarampampam/error-pages#-templates)' ghost l7-light l7-dark shuffle noise hacker-terminal cats lost-in-space app-down connection matrix orient)"
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
        echo "## No routes defined." >/dev/stderr
        return
    fi
    echo "## Configured Routes:" >/dev/stderr
    (echo "${ROUTES}" | tr ',' '\n' | sed 's/:/\t/g' | sort -u) | column -t
}

layer_7_tls_proxy_add_ingress_route() {
    echo "Adding new layer 7 TLS proxy route - "
    echo
    echo " * Make sure to set your route DNS to point to this Traefik instance."
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
            echo "Route port is invalid."
            continue
        fi
        false
    do true; done
    local ROUTES=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_LAYER_7_TLS_PROXY_ROUTES)
    if [[ -n "${ROUTES}" ]]; then
        ROUTES="${ROUTES},"
    fi
    ROUTES="${ROUTES}${ROUTE_DOMAIN}:${ROUTE_IP_ADDRESS}:${ROUTE_PORT}"
    ${BIN}/reconfigure ${ENV_FILE} "TRAEFIK_LAYER_7_TLS_PROXY_ROUTES=${ROUTES}"
}

layer_7_tls_proxy_manage_ingress_routes() {
    mapfile -t routes < <( layer_7_tls_proxy_get_routes )
    if [[ "${#routes[@]}" == 0 ]]; then
        return
    fi
    mapfile -t to_delete < <(wizard select "Select routes to DELETE:" "${routes[@]}")
    debug_array to_delete
    echo
    if confirm no "Do you really want to delete these routes" "?"; then
        local ROUTES_TMP=$(mktemp)
        local TO_DELETE_TMP=$(mktemp)
        local ROUTES_EDIT=$(mktemp)
        (IFS=$'\n'; echo "${routes[*]}") | sort -u > "${ROUTES_TMP}"
        (IFS=$'\n'; echo "${to_delete[*]}") | sort -u > "${TO_DELETE_TMP}"
        local ROUTES=$(comm -23 "${ROUTES_TMP}" "${TO_DELETE_TMP}" | tr '\t' ':' | tr '\n' ',')
        echo ok
        ${BIN}/reconfigure ${ENV_FILE} "TRAEFIK_LAYER_7_TLS_PROXY_ROUTES=${ROUTES}"
    fi
    echo
    layer_7_tls_proxy_get_routes
}

layer_7_tls_proxy_disable() {
    local ENABLED=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_LAYER_7_TLS_PROXY_ENABLED)
    if [[ "${ENABLED}" == "true" ]]; then
        confirm yes "Do you want to disable the layer 7 TLS proxy" "?" && \
            ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_LAYER_7_TLS_PROXY_ENABLED=false
        echo "## Layer 7 TLS Proxy is DISABLED."
        exit 2
    else
        fault "TRAEFIK_LAYER_7_TLS_PROXY_ENABLED already disabled!?"
    fi
}

layer_7_tls_proxy() {
    echo "## Layer 7 TLS Proxy can forward TLS connections to direct IP addresses."
    echo
    local ENABLED=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_LAYER_7_TLS_PROXY_ENABLED)
    if [[ "${ENABLED}" == "true" ]]; then
        echo
        echo "## Layer 7 TLS Proxy is ENABLED."
        layer_7_tls_proxy_get_routes
        wizard menu "Layer 7 TLS Proxy:" \
               "List layer 7 ingress routes = ./setup.sh layer_7_tls_proxy_get_routes" \
               "Add new layer 7 ingress route = ./setup.sh layer_7_tls_proxy_add_ingress_route" \
               "Remove layer 7 ingress routes = ./setup.sh layer_7_tls_proxy_manage_ingress_routes" \
               "Disable layer 7 TLS Proxy = ./setup.sh layer_7_tls_proxy_disable" \
               "Exit = exit 2"
    else
        echo "## Layer 7 TLS Proxy is DISABLED."
        confirm no "Do you want to enable the layer 7 TLS proxy" "?" && \
            ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_LAYER_7_TLS_PROXY_ENABLED=true && \
            layer_7_tls_proxy || true
    fi
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
              TRAEFIK_DASHBOARD_ENTRYPOINT_HOST=127.0.0.1
        set_all_entrypoint_host 0.0.0.0
    }
    set_wireguard_server() {
        ${BIN}/reconfigure ${ENV_FILE} \
              TRAEFIK_VPN_ENABLED=true \
              TRAEFIK_VPN_CLIENT_ENABLED=false \
              TRAEFIK_DASHBOARD_ENTRYPOINT_HOST=127.0.0.1
        echo
        case $(wizard choose --numeric \
               "Should Traefik bind itself exclusively to the VPN interface?" \
               "No, Traefik should work on all interfaces (including the VPN)." \
               "Yes, Traefik should only listen on the VPN interface." \
               "Cancel / Go back.") in
            0) set_all_entrypoint_host 0.0.0.0;;
            1) set_all_entrypoint_host $(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ADDRESS);;
            *) return;;
        esac        
    }
    set_wireguard_client() {
        ${BIN}/reconfigure ${ENV_FILE} \
              TRAEFIK_VPN_ENABLED=false \
              TRAEFIK_VPN_CLIENT_ENABLED=true \
              TRAEFIK_DASHBOARD_ENTRYPOINT_HOST=127.0.0.1
        echo
        case $(wizard choose --numeric \
               "Should Traefik bind itself exclusively to the VPN interface?" \
               "No, Traefik should work on all interfaces (including the VPN)." \
               "Yes, Traefik should only listen on the VPN interface." \
               "Cancel / Go back.") in
            0) set_all_entrypoint_host 0.0.0.0;;
            1) set_all_entrypoint_host $(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_CLIENT_INTERFACE_ADDRESS);;
            *) return;;
        esac

    }    
    case $(wizard choose --numeric \
           "Should this Traefik instance connect to a wireguard VPN?" \
           "No, Traefik should use the host network directly." \
           "Yes, and this Traefik instance should start the wireguard server." \
           "Yes, but this Traefik instance needs credentials to connect to an outside VPN." \
           "Cancel / Go back.") in
        0) set_public_no_wireguard;;
        1) set_wireguard_server;;
        2) set_wireguard_client;;
        3) exit 2;;
        *) fault "Wizard choose overflow!?";;
    esac
}

# wireguard() {
#     wireguard_server() {
#         wireguard_disable_client
#         ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_HOST "Enter the public Traefik VPN hostname" ${ROOT_DOMAIN}
# 	    #${BIN}/reconfigure ${ENV_FILE} TRAEFIK_VPN_ROOT_DOMAIN=${ROOT_DOMAIN}
# 	    ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_SUBNET "Enter the Traefik VPN private subnet (no mask)"
# 	    ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_ADDRESS "Enter the Traefik VPN private IP address" 10.13.16.1
# 	    ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_PORT "Enter the Traefik VPN TCP port number"
# 	    ${BIN}/reconfigure_ask_multi ${ENV_FILE} TRAEFIK_WEB_ENTRYPOINT_HOST,TRAEFIK_WEBSECURE_ENTRYPOINT_HOST,TRAEFIK_WEB_PLAIN_ENTRYPOINT_HOST,TRAEFIK_MQTT_ENTRYPOINT_HOST,TRAEFIK_SSH_ENTRYPOINT_HOST,TRAEFIK_XMPP_C2S_ENTRYPOINT_HOST,TRAEFIK_XMPP_S2S_ENTRYPOINT_HOST,TRAEFIK_MPD_ENTRYPOINT_HOST,TRAEFIK_REDIS_ENTRYPOINT_HOST,TRAEFIK_SNAPCAST_ENTRYPOINT_HOST,TRAEFIK_SNAPCAST_CONTROL_ENTRYPOINT_HOST "Enter the private VPN IP address to bind all the Traefik entrypoints to" 10.13.16.1
# 	    ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_VPN_ENABLED=true TRAEFIK_NETWORK_MODE=service:wireguard TRAEFIK_VPN_ALLOWED_IPS=$(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_SUBNET)/24 TRAEFIK_DASHBOARD_ENTRYPOINT_HOST="0.0.0.0"
# 	    ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_PEERS "Enter the Traefik VPN peers list"
#     }
#     wireguard_client() {
#         echo ""
#         wireguard_disable_server
# 	    ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_ROOT_DOMAIN "Enter the ROOT_DOMAIN used by the server config"
# 	    ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_CLIENT_PEER_SERVICES "Enter the list of VPN service names that the client should reverse proxy (comma separated; hostnames only)" whoami
# 	    echo "Scan the QR code for the client credentials printed in the wireguard server's log. Copy the details from the decoded QR code (The first line should be: [Interface]):"
# 	    ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_CLIENT_INTERFACE_ADDRESS "Enter the wireguard client Interface Address"
# 	    ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_CLIENT_INTERFACE_PRIVATE_KEY "Enter the wireguard PrivateKey (ends with =)"
# 	    ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_CLIENT_INTERFACE_LISTEN_PORT "Enter the wireguard listen port" 51820
# 	    ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_CLIENT_INTERFACE_PEER_DNS "Enter the wireguard Interface DNS" 10.13.16.1
# 	    ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_CLIENT_PEER_PUBLIC_KEY "Enter the Peer PublicKey (ends with =)"
# 	    ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_CLIENT_PEER_PRESHARED_KEY "Enter the Peer PresharedKey (ends with =)"
# 	    ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_CLIENT_PEER_ENDPOINT "Enter the Peer Endpoint (host:port)"
# 	    ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_CLIENT_PEER_ALLOWED_IPS "Enter the Peer AllowedIPs"
# 	    ${BIN}/reconfigure_ask ${ENV_FILE} TRAEFIK_VPN_ADDRESS "Enter the Traefik VPN private IP address" 10.13.16.1
# 	    ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_VPN_CLIENT_ENABLED=true TRAEFIK_NETWORK_MODE=service:wireguard-client TRAEFIK_DASHBOARD_ENTRYPOINT_HOST="0.0.0.0"
#     }
#     wireguard_disable_server() {
#         ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_VPN_ENABLED=false
# 	    ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_DASHBOARD_ENTRYPOINT_HOST=127.0.0.1 TRAEFIK_WEB_ENTRYPOINT_HOST=0.0.0.0 TRAEFIK_WEBSECURE_ENTRYPOINT_HOST=0.0.0.0 TRAEFIK_WEB_PLAIN_ENTRYPOINT_HOST=0.0.0.0 TRAEFIK_MQTT_ENTRYPOINT_HOST=0.0.0.0 TRAEFIK_SSH_ENTRYPOINT_HOST=0.0.0.0 TRAEFIK_XMPP_C2S_ENTRYPOINT_HOST=0.0.0.0 TRAEFIK_XMPP_S2S_ENTRYPOINT_HOST=0.0.0.0 TRAEFIK_MPD_ENTRYPOINT_HOST=0.0.0.0 TRAEFIK_SNAPCAST_ENTRYPOINT_HOST=0.0.0.0 TRAEFIK_SNAPCAST_CONTROL_ENTRYPOINT_HOST=0.0.0.0
#     }
#     wireguard_disable_client() {
#         ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_VPN_CLIENT_ENABLED=false
#     }
    
#     if ${BIN}/confirm $([[ $(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ENABLED) == "true" ]] && echo "yes" || echo "no") "Do you want to run Traefik exclusively in a VPN? (wireguard server mode)" "?"; then
#         wireguard_server
#     else
#         wireguard_disable_server
#     fi
# 	echo ""
# 	if [[ $(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ENABLED) != "true" ]]; then
#         if ${BIN}/confirm $([[ $(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_CLIENT_ENABLED) == "true" ]] && echo "yes" || echo "no") "Do you want to run Traefik as a reverse proxy (public ingress) into a VPN? (wireguard client mode)" "?"; then
#             wireguard_client
#         else
#             wireguard_disable_client
#         fi
#     fi
# 	if [[ $(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_ENABLED) != "true" ]] && [[ $(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_VPN_CLIENT_ENABLED) != "true" ]]; then
#         ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_NETWORK_MODE=host TRAEFIK_DASHBOARD_ENTRYPOINT_HOST=127.0.0.1
#     fi
# 	make --no-print-directory compose-profiles
# }

echo
check_var ENV_FILE

$@
