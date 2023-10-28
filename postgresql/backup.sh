#!/bin/bash

BIN=../_scripts
source ${BIN}/funcs.sh

check_var ENV_FILE
echo ENV_FILE=${ENV_FILE}
echo INSTANCE=${INSTANCE:-default}
echo INSTANCE_SUFFIX=${INSTANCE_SUFFIX:-_default}
export PROJECT_NAME
export INSTANCE
export INSTANCE_SUFFIX
export ENV_FILE

pgbackrest_cmd() {
    local EXTRA_ARGS=("--stanza=apps" "--log-level-console=info")
    if [[ "backup" == "$1" ]]; then
        EXTRA_ARGS+=("--annotation=context=${DOCKER_CONTEXT}" "--annotation=instance=${INSTANCE}")
    fi
    EXTRA_ARGS+=($@)
    EXTRA_ARGS="${EXTRA_ARGS[@]}"
    docker_compose exec -u postgres postgres sh -c "set -x; pgbackrest ${EXTRA_ARGS}"
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

set -e
wait_for_ready
pgbackrest_cmd stanza-create
backup_local
backup_s3
pgbackrest_cmd info
pgbackrest_cmd check
