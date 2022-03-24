#!/bin/bash

BIN=../_scripts
ENV_FILE=.env_$(${BIN}/docker_context)

USERNAME=archivebox
CONTAINER=$(docker-compose --env-file=${ENV_FILE} ps -q archivebox)

## pass args and stdin to the container archivebox command:
docker exec -i -u ${USERNAME} ${CONTAINER} archivebox "${@}"
