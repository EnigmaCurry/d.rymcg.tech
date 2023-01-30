#!/bin/bash

BIN=$(dirname ${BASH_SOURCE})
ROOT_DIR=${ROOT_DIR:-$(dirname ${BIN})}

error(){ echo "Error: $@" >/dev/stderr; }
fault(){ test -n "$1" && error $1; echo "Exiting." >/dev/stderr; exit 1; }
exe() { (set -x; "$@"); }
check_var(){
    __missing=false
    __vars="$@"
    for __var in ${__vars}; do
        if [[ -z "${!__var}" ]]; then
            error "${__var} variable is missing."
            __missing=true
        fi
    done
    if [[ ${__missing} == true ]]; then
        fault
    fi
}

ask() {
    __prompt=${1}; __var=${2}; __default=${3}
    read -e -p "${__prompt}"$'\x0a: ' -i "${__default}" ${__var}
    export ${__var}
}

ask_no_blank() {
    __prompt=${1}; __var=${2}; __default=${3}
    while true; do
        read -e -p "${__prompt}"$'\x0a: ' -i "${__default}" ${__var}
        export ${__var}
        [[ -z "${!__var}" ]] || break
    done
}

require_input() {
    ## require_input {PROMPT} {VAR} {DEFAULT}
    ## Read variable, set default if blank, error if still blank
    test -z ${3} && dflt="" || dflt=" (${3})"
    read -e -p "$1$dflt: " $2
    eval $2=${!2:-${3}}
    test -v ${!2} && fault "$2 must not be blank."
}

docker_run_with_env() {
    ## Runs docker container with the listed environment variables set.
    ## Pass VARS as the name of an array containing the env var names.
    ## Pass the rest of the docker run args after that.
    ## docker_run_with_env VARS {rest of docker run command args}..
    docker_env() {
        ## construct the env var args string
        ## First arg is the string to return
        declare -n returned_string=$1; shift;
        ## The rest of the args are the names of the environment vars:
        ## Return a string full of all the docker environment vars and values
        __args=""; for var in "$@"; do
                       test -z ${!var} && fault "$var is not set!"
                       __args="${__args} -e $var=${!var}"
                   done
        returned_string="${__args}"
    }
    ## Get the array of vars passed by name:
    name=$1[@]; ___vars=("${!name}"); ___vars=${___vars[@]}; shift;
    ## Construct the env var args string and put into DOCKER_ENV:
    docker_env DOCKER_ENV $___vars
    ## Run Docker with the environment set and the rest of the args sent:
    set -x
    docker run ${DOCKER_ENV} $*
}

get_root_domain() {
    ENV_FILE=${BIN}/../.env_$(${BIN}/docker_context)
    if [[ -f ${ENV_FILE} ]]; then
        ${BIN}/dotenv -f ${ENV_FILE} get ROOT_DOMAIN
    else
        echo "Could not find $(abspath ${ENV_FILE})"
        fault "Run `make config` in the root project directory first."
    fi
}

docker_compose() {
    ENV_FILE=${ENV_FILE:-.env_$(${BIN}/docker_context)}
    PROJECT_NAME="$(basename $PWD)"
    if [[ -n "${instance:-${INSTANCE}}" ]] && [[ "${ENV_FILE}" != ".env_${DOCKER_CONTEXT}_${instance:-${INSTANCE}}" ]]; then
        ENV_FILE="${ENV_FILE}_${instance:-${INSTANCE}}"
        PROJECT_NAME="$(basename $PWD)_${instance:-${INSTANCE}}"
    fi
    set -ex
    docker compose ${DOCKER_COMPOSE_FILE_ARGS:--f docker-compose.yaml} --env-file="${ENV_FILE}" --project-name="${PROJECT_NAME}" "$@"
}

docker_run() {
    ENV_FILE=${ENV_FILE:-.env_$(${BIN}/docker_context)}
    PROJECT_NAME="$(basename $PWD)"
    if [[ -n "${instance:-${INSTANCE}}" ]] && [[ "${ENV_FILE}" != ".env_${DOCKER_CONTEXT}_${instance:-${INSTANCE}}" ]]; then
        ENV_FILE="${ENV_FILE}_${instance:-${INSTANCE}}"
        PROJECT_NAME="$(basename $PWD)_${instance:-${INSTANCE}}"
    fi
    set -ex
    docker run --rm --env-file=${ENV_FILE} "$@"
}

docker_exec() {
    ENV_FILE=${ENV_FILE:-.env_$(${BIN}/docker_context)}
    PROJECT_NAME="$(basename $PWD)"
    if [[ -n "${instance:-${INSTANCE}}" ]] && [[ "${ENV_FILE}" != ".env_${DOCKER_CONTEXT}_${instance:-${INSTANCE}}" ]]; then
        ENV_FILE="${ENV_FILE}_${instance:-${INSTANCE}}"
        PROJECT_NAME="$(basename $PWD)_${instance:-${INSTANCE}}"
    fi
    set -ex
    docker exec --env-file=${ENV_FILE} "$@"
}

ytt() {
    set -e
    docker image inspect localhost/ytt >/dev/null || docker build -t localhost/ytt -f- . >/dev/null <<'EOF'
FROM debian:stable-slim as ytt
ARG YTT_VERSION=v0.44.3
RUN apt-get update && apt-get install -y wget && wget "https://github.com/vmware-tanzu/carvel-ytt/releases/download/${YTT_VERSION}/ytt-linux-$(dpkg --print-architecture)" -O ytt && install ytt /usr/local/bin/ytt
EOF
    non_template_commands_pattern="(help|completion|fmt|version)"
    if [[ "$@" == "" ]]; then
        CMD="docker run --rm -i localhost/ytt ytt help"
    elif [[ "$1" =~ $non_template_commands_pattern ]]; then
        CMD="docker run --rm -i localhost/ytt ytt ${@}"
    else
        CMD="docker run --rm -i localhost/ytt ytt -f- ${@}"
    fi
    eval $CMD
}

volume_rsync() {
    docker image inspect localhost/rsync >/dev/null || docker build -t localhost/rsync ${ROOT_DIR}/_terminal/rsync
    if [[ $# -gt 0 ]]; then
        VOLUME="${1}"; shift
        docker volume inspect "${VOLUME}" >/dev/null
        rsync --rsh="docker run -i --rm -v ${VOLUME}:/data -w /data localhost/rsync" "$@"
    else
        fault "Usage: volume_ls VOLUME_NAME {ARGS}"
    fi
}

volume_ls() {
    if [[ $# -gt 0 ]]; then
        VOLUME="${1}"; shift
        docker run --rm -i -v "${VOLUME}:/data" -w /data alpine find
    else
        fault "Usage: volume_ls VOLUME_NAME"
    fi
}

volume_mkdir() {
    if [[ $# -gt 0 ]]; then
        VOLUME="${1}"; shift
        docker volume create "${VOLUME}"
        docker run --rm -i -v "${VOLUME}:/data" -w /data alpine mkdir -p "$@"
    else
        fault "Usage: volume_mkdir [PATH ...]"
    fi
}
