#!/bin/bash

BIN=${ROOT_DIR}/_scripts
source ${BIN}/funcs.sh

ROOT_DOMAIN=$(get_root_domain)
DOCKER_CONTEXT=$(${BIN}/docker_context)

PUBLIC_HTTPS_PORT=$(${BIN}/dotenv -f ../.env_${DOCKER_CONTEXT} get PUBLIC_HTTPS_PORT);
if [[ "$PUBLIC_HTTPS_PORT" == "443" ]]; then
    PUBLIC_HTTPS_PORT=""
else
    PUBLIC_HTTPS_PORT=":${PUBLIC_HTTPS_PORT}"
fi
${BIN}/reconfigure ${ENV_FILE} TRAEFIK_FORWARD_AUTH_HTTPS_PORT=${PUBLIC_HTTPS_PORT}
