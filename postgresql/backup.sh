#!/bin/bash

BIN=../_scripts
source ${BIN}/funcs.sh

check_var ENV_FILE
echo ENV_FILE=${ENV_FILE}
echo INSTANCE=${INSTANCE}
echo INSTANCE_SUFFIX=${INSTANCE_SUFFIX}
export PROJECT_NAME
export INSTANCE
export INSTNACE_SUFFIX
export ENV_FILE

pgbackrest_cmd() {
    local EXTRA_ARGS=("--stanza=apps" "--log-level-console=info")
    if [[ "backup" == "$1" ]]; then
        EXTRA_ARGS+=("--annotation=context=${DOCKER_CONTEXT}" "--annotation=instance=${INSTANCE}")
    fi
    EXTRA_ARGS="${EXTRA_ARGS[@]}"
    docker_compose exec -u postgres postgres sh -c "set -x; pgbackrest ${EXTRA_ARGS} $@"
}

restart() {
    make --no-print-directory restart
    docker_wait_for_healthcheck $(make --no-print-directory docker-compose-lifecycle-cmd EXTRA_ARGS="ps -a postgres -q")
}

set -e
pgbackrest_cmd stanza-create
pgbackrest_cmd check
pgbackrest_cmd backup
pgbackrest_cmd info

#pgbackrest_cmd restore
