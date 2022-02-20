#!/bin/bash

## Import common functions:
BIN=$(dirname ${BASH_SOURCE[0]})/../_scripts
source ${BIN}/funcs.sh
source $(dirname ${BASH_SOURCE[0]})/../_terminal/linux/shell.sh

mc() {
    shell_container persistent=true template=mc image=quay.io/minio/mc ${@}
}

## Start persistent container so we can temporarily cache the mc credentials
mc --start

MINIO_TRAEFIK_HOST=$(${BIN}/dotenv -f ${ENV_FILE} get MINIO_TRAEFIK_HOST)
MINIO_ROOT_USER=$(${BIN}/dotenv -f ${ENV_FILE} get MINIO_ROOT_USER)
MINIO_ROOT_PASSWORD=$(${BIN}/dotenv -f ${ENV_FILE} get MINIO_ROOT_PASSWORD)

## Configure endpoint with root credentials:
COMMAND="mc alias set minio https://${MINIO_TRAEFIK_HOST} ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}" mc --exec

## Start shell
mc

## Stop the container
YES=yes mc --rm
