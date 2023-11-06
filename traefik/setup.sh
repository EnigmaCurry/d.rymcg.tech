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
    separator '###' 60 "Traefik Config"
    echo "For first time setup, visit each of the following menu items, in order."
    echo "For reconfiguration, you can skip to the section you want:"
    wizard menu "Traefik config main menu:" \
           "Create Traefik system user on Docker host = ./setup.sh traefik_user" \
           "Configure dashboard = ./setup.sh dashboard" \
           "Configure ACME (Let's Encrypt) = make config-acme" \
           "Configure TLS certificates and domains = make certs" \
           "Exit = exit 2"
}

everything() {
    traefik_user
    ## The user just configured everything, they don't need to go back to the menu.
    ## Exit with code 2, so it won't raise a general error:
    exit 2
}

traefik_user() {
    SSH_HOST=$(docker context inspect | jq -r ".[0].Endpoints.docker.Host");
    if [[ "${SSH_HOST}" == unix://* ]]; then
        echo "Not creating the traefik-user because there is no SSH context."
        echo
        echo "You will have to create the traefik user on the server,"
        echo "and set TRAEFIK_UID and TRAEFIK_GID by hand."
        echo
    else
        SSH_UID=$(ssh ${SSH_HOST} id -u);
        [[ $SSH_UID != "0" ]] && SUDO_PREFIX="sudo" || SUDO_PREFIX="";
        if ssh ${SSH_HOST} id traefik; then
            echo "Traefik user already exists."
        else
            ssh ${SSH_HOST} ${SUDO_PREFIX} adduser \
                --disabled-login --disabled-password \
                --gecos GECOS traefik && \
                ssh ${SSH_HOST} ${SUDO_PREFIX} gpasswd -a traefik docker || fault "There was a problem creating the traefik user. You must create the traefik user on the Docker host by hand, and set the TRAEFIK_UID and TRAEFIK_GID in the .env file."
        fi
    fi
}

traefik_uid() {
    SSH_HOST=$(docker context inspect | jq -r ".[0].Endpoints.docker.Host");
    if [[ "${SSH_HOST}" == unix://* ]]; then
        ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_UID=1000 TRAEFIK_GID=1000
        ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_DOCKER_GID=$(getent group docker | cut -d ':' -f 3);
    else
        TRAEFIK_UID=$(ssh ${SSH_HOST} id -u traefik)
        TRAEFIK_GID=$(ssh ${SSH_HOST} id -g traefik)
        TRAEFIK_DOCKER_GID=$(ssh ${SSH_HOST} getent group docker | cut -d: -f3)
        exe ${BIN}/reconfigure ${ENV_FILE} \
              TRAEFIK_UID=${TRAEFIK_UID} \
              TRAEFIK_GID=${TRAEFIK_GID} \
              TRAEFIK_DOCKER_GID=${TRAEFIK_DOCKER_GID}
    fi
}

dashboard() {
    ## Make new .env if it doesn't exist:
    test -f ${ENV_FILE} || cp ./.env-dist ${ENV_FILE}
    echo ""
    if ${BIN}/confirm $([[ $(${BIN}/dotenv -f ${ENV_FILE} get TRAEFIK_DASHBOARD_ENTRYPOINT_ENABLED) == "true" ]] && echo yes || echo no) "Do you want to enable the Traefik dashboard" "?"; then
        ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_DASHBOARD_ENTRYPOINT_ENABLED=true
        echo
        echo "It's important to protect the dashboard and so a username/password is required."
	    __D_RY_CONFIG_ENTRY=reconfigure_auth ${BIN}/reconfigure_htpasswd ${ENV_FILE} TRAEFIK_DASHBOARD_HTTP_AUTH
    else
        ${BIN}/reconfigure ${ENV_FILE} TRAEFIK_DASHBOARD_ENTRYPOINT_ENABLED=false
    fi
}

if [[ "$#" != 1 ]]; then
    fault "Wrong number of arguments. Try running \`make config\` instead."
fi

echo
check_var ENV_FILE

$1
