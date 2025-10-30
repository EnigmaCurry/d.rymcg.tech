#!/bin/bash

set -e

if [[ -z "$ROOT_DIR" ]]; then
    echo "ROOT_DIR not set"
    exit 1
fi

BIN=${ROOT_DIR}/_scripts
source ${BIN}/funcs.sh
check_var ENV_FILE

FILEBROWSER_OAUTH2=$(${BIN}/dotenv -f ${ENV_FILE} get FILEBROWSER_OAUTH2)
FILEBROWSER_HTTP_AUTH=$(${BIN}/dotenv -f ${ENV_FILE} get FILEBROWSER_HTTP_AUTH)
FILEBROWSER_MTLS_AUTH=$(${BIN}/dotenv -f ${ENV_FILE} get FILEBROWSER_MTLS_AUTH)

if [[ "$FILEBROWSER_OAUTH2" == "true" ]]; then
    ${BIN}/dotenv -f ${ENV_FILE} set FILEBROWSER_AUTH_TYPE=proxy
else
    ${BIN}/dotenv -f ${ENV_FILE} set FILEBROWSER_AUTH_TYPE=json
fi
