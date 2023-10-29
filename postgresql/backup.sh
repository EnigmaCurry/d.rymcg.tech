#!/bin/bash

BIN=../_scripts
source ${BIN}/funcs.sh

check_var ENV_FILE
POSTGRES_INSTANCE=$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_INSTANCE)
POSTGRES_HOST=$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_HOST)
export PROJECT_NAME
export INSTANCE
export INSTANCE_SUFFIX
export ENV_FILE

pgbackrest_cmd() {
    local EXTRA_ARGS=("--stanza=apps" "--log-level-console=info")
    if [[ "backup" == "$1" ]]; then
        EXTRA_ARGS+=("--annotation=postgres-host=${POSTGRES_HOST}" "--annotation=instance=${POSTGRES_INSTANCE} ")
    fi
    EXTRA_ARGS+=($@)
    EXTRA_ARGS="${EXTRA_ARGS[@]}"
    docker_compose exec -u postgres postgres sh -c "set -x; pgbackrest ${EXTRA_ARGS}"
}

remove_all_data() {
    docker_compose exec -u postgres postgres sh -c "set -x; rm -rf /var/lib/postgresql/data/*"
}


wait_for_ready() {
    docker_wait_for_healthcheck $(make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="ps -a postgres -q")
}

restart() {
    make --no-print-directory restart
    wait_for_ready
}

backup_local() {
    if [[ "$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_PGBACKREST_LOCAL)"  == "true" ]]; then
        pgbackrest_cmd backup --repo=1
    else
        echo "## Skipping local backup as POSTGRES_PGBACKREST_LOCAL != true"
    fi
}

backup_s3() {
    if [[ "$(${BIN}/dotenv -f ${ENV_FILE} get POSTGRES_PGBACKREST_S3)"  == "true" ]]; then
        pgbackrest_cmd backup --repo=2
    else
        echo "## Skipping local backup as POSTGRES_PGBACKREST_S3 != true"
    fi
}

restore() {
    ${BIN}/confirm no "WARNING: This process will DELETE all current database files and restore from the latest S3 backup"
    make --no-print-directory stop ensure-stopped
    ${BIN}/reconfigure ${ENV_FILE} POSTGRES_MAINTAINANCE_MODE="true"
    restart
    remove_all_data
    pgbackrest_cmd restore --repo=2
    sleep 2
    make --no-print-directory stop ensure-stopped
    ${BIN}/reconfigure ${ENV_FILE} POSTGRES_MAINTAINANCE_MODE="false"
    echo "Maintainance finished. Run \`make start\` when you're ready to restart the database."
}

set -e

cmd=$1; shift;
case "${cmd}" in
    now)
        wait_for_ready
        pgbackrest_cmd stanza-create
        backup_local
        backup_s3
        pgbackrest_cmd info
        pgbackrest_cmd check
        ;;
    restore)
        restore
        ;;
    *)
        echo "invalid command"
        exit 1
esac
