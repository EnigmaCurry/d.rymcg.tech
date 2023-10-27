#!/bin/bash

BIN=../_scripts
source ${BIN}/funcs.sh

configure_pgbackrest() {
}

create_pgbackrest_stanza() {
    docker_compose exec postgres sh -c "pgbackrest --stanza=apps --log-level-console=info stanza-create"

}

set -e
configure_pgbackrest
create_pgbackrest_stanza
