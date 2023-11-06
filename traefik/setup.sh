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
    echo "For first time setup, visit each of the following menu items, in order."
    echo "When re-configuring, you may skip to the section you want:"
    wizard menu "Traefik config main menu:" \
           "Create system user on Docker host = ./setup.sh traefik_user" \
           "Configure entrypoints (including dashboard) = ./setup.sh entrypoints" \
           "Configure error page template = ./setup.sh error_pages" \
           "Configure ACME (Let's Encrypt) = make config-acme" \
           "Configure TLS certificates and domains (make certs) = make certs" \
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
                ssh ${SSH_HOST} ${SUDO_PREFIX} adduser \
                    --disabled-login --disabled-password \
                    --gecos GECOS ${TRAEFIK_USER} && \
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
           "Configure all entrypoints = ./setup.sh config_list_entrypoints"
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

echo
check_var ENV_FILE

$@
