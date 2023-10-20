#!/bin/bash

BIN=$(dirname ${BASH_SOURCE})
ROOT_DIR=${ROOT_DIR:-$(dirname ${BIN})}

error(){ echo "Error: $@" >/dev/stderr; }
fault(){ test -n "$1" && error $1; echo "Exiting." >/dev/stderr; exit 1; }
exe() { (set -x; "$@"); }
check_var(){
    local __missing=false
    local __vars="$@"
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

check_num(){
    local var=$1
    check_var var
    if ! [[ ${!var} =~ ^[0-9]+$ ]] ; then
        fault "${var} is not a number: '${!var}'"
    fi
}

ask() {
    ## Ask the user a question and set the given variable name with their answer
    local __prompt="${1}"; local __var="${2}"; local __default="${3}"
    read -e -p "${__prompt}"$'\x0a\e[32m:\e[0m ' -i "${__default}" ${__var}
    export ${__var}
}

ask_no_blank() {
    ## Ask the user a question and set the given variable name with their answer
    ## If the answer is blank, repeat the question.
    local __prompt="${1}"; local __var="${2}"; local __default="${3}"
    while true; do
        read -e -p "${__prompt}"$'\x0a\e[32m:\e[0m ' -i "${__default}" ${__var}
        export ${__var}
        [[ -z "${!__var}" ]] || break
    done
}

ask_echo() {
    ## Ask the user a question then print the non-blank answer to stdout
    (
        ask_no_blank "$1" ASK_ECHO_VARNAME >/dev/stderr
        echo "${ASK_ECHO_VARNAME}"
    )
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
        local __args=""; for var in "$@"; do
                       test -z ${!var} && fault "$var is not set!"
                       __args="${__args} -e $var=${!var}"
                   done
        returned_string="${__args}"
    }
    ## Get the array of vars passed by name:
    local name=$1[@]; local ___vars=("${!name}"); ___vars=${___vars[@]}; shift;
    ## Construct the env var args string and put into DOCKER_ENV:
    docker_env DOCKER_ENV $___vars
    ## Run Docker with the environment set and the rest of the args sent:
    set -x
    docker run ${DOCKER_ENV} $*
}

get_root_domain() {
    local ENV_FILE=${BIN}/../.env_$(${BIN}/docker_context)
    if [[ -f ${ENV_FILE} ]]; then
        ${BIN}/dotenv -f ${ENV_FILE} get ROOT_DOMAIN
    else
        echo "Could not find $(abspath ${ENV_FILE})"
        fault "Run `make config` in the root project directory first."
    fi
}

docker_compose() {
    local ENV_FILE=${ENV_FILE:-.env_$(${BIN}/docker_context)}
    local PROJECT_NAME="$(basename \"$PWD\")"
    if [[ -n "${instance:-${INSTANCE}}" ]] && [[ "${ENV_FILE}" != ".env_${DOCKER_CONTEXT}_${instance:-${INSTANCE}}" ]]; then
        ENV_FILE="${ENV_FILE}_${instance:-${INSTANCE}}"
        PROJECT_NAME="$(basename \"$PWD\")_${instance:-${INSTANCE}}"
    fi
    set -ex
    docker compose ${DOCKER_COMPOSE_FILE_ARGS:--f docker-compose.yaml} --env-file="${ENV_FILE}" --project-name="${PROJECT_NAME}" "$@"
}

docker_run() {
    local ENV_FILE=${ENV_FILE:-.env_$(${BIN}/docker_context)}
    local PROJECT_NAME="$(basename \"$PWD\")"
    if [[ -n "${instance:-${INSTANCE}}" ]] && [[ "${ENV_FILE}" != ".env_${DOCKER_CONTEXT}_${instance:-${INSTANCE}}" ]]; then
        ENV_FILE="${ENV_FILE}_${instance:-${INSTANCE}}"
        PROJECT_NAME="$(basename \"$PWD\")_${instance:-${INSTANCE}}"
    fi
    set -ex
    docker run --rm --env-file=${ENV_FILE} "$@"
}

docker_exec() {
    local ENV_FILE=${ENV_FILE:-.env_$(${BIN}/docker_context)}
    local PROJECT_NAME="$(basename \"$PWD\")"
    if [[ -n "${instance:-${INSTANCE}}" ]] && [[ "${ENV_FILE}" != ".env_${DOCKER_CONTEXT}_${instance:-${INSTANCE}}" ]]; then
        ENV_FILE="${ENV_FILE}_${instance:-${INSTANCE}}"
        PROJECT_NAME="$(basename \"$PWD\")_${instance:-${INSTANCE}}"
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
        local VOLUME="${1}"; shift
        docker volume inspect "${VOLUME}" >/dev/null
        rsync --rsh="docker run -i --rm -v ${VOLUME}:/data -w /data localhost/rsync" "$@"
    else
        fault "Usage: volume_ls VOLUME_NAME {ARGS}"
    fi
}

volume_ls() {
    if [[ $# -gt 0 ]]; then
        local VOLUME="${1}"; shift
        docker run --rm -i -v "${VOLUME}:/data" -w /data alpine find
    else
        fault "Usage: volume_ls VOLUME_NAME"
    fi
}

volume_mkdir() {
    if [[ $# -gt 0 ]]; then
        local VOLUME="${1}"; shift
        exe docker volume create "${VOLUME}"
        if [[ $# -gt 0 ]]; then
            exe docker run --rm -i -v "${VOLUME}:/data" -w /data alpine mkdir -p "$@"
        fi
    else
        fault "Usage: volume_mkdir [PATH ...]"
    fi
}

random_port() {
    local LOW_PORT="${1:-49152}"; HIGH_PORT="${2:-65535}"
    comm -23 <(seq "${LOW_PORT}" "${HIGH_PORT}") <(ss -tan | awk '{print $4}' | cut -d':' -f2 | \
                                                       grep "[0-9]\{1,5\}" | sort | uniq) 2>/dev/null | \
        shuf 2>/dev/null | head -n 1; true
}

wizard() {
    ${BIN}/script-wizard "$@"
}

color() {
    ## Print text in ANSI color
    set -e
    if [[ $# -lt 2 ]]; then
        fault "Not enough args: expected COLOR and TEXT arguments"
    fi
    local COLOR_CODE_PREFIX='\033['
    local COLOR_CODE_SUFFIX='m'
    local COLOR=$1; shift
    local TEXT="$*"
    local LIGHT=1
    check_var COLOR TEXT
    case "${COLOR}" in
        "black") COLOR=30; LIGHT=0;;
        "red") COLOR=31; LIGHT=0;;
        "green") COLOR=32; LIGHT=0;;
        "brown") COLOR=33; LIGHT=0;;
        "orange") COLOR=33; LIGHT=0;;
        "blue") COLOR=34; LIGHT=0;;
        "purple") COLOR=35; LIGHT=0;;
        "cyan") COLOR=36; LIGHT=0;;
        "light gray") COLOR=37; LIGHT=0;;
        "dark gray") COLOR=30; LIGHT=1;;
        "light red") COLOR=31; LIGHT=1;;
        "light green") COLOR=32; LIGHT=1;;
        "yellow") COLOR=33; LIGHT=1;;
        "light blue") COLOR=34; LIGHT=1;;
        "light purple") COLOR=35; LIGHT=1;;
        "light cyan") COLOR=36; LIGHT=1;;
        "white") COLOR=37; LIGHT=1;;
        *) fault "Unknown color"
    esac
    echo -en "${COLOR_CODE_PREFIX}${LIGHT};${COLOR}${COLOR_CODE_SUFFIX}${TEXT}${COLOR_CODE_PREFIX}0;0${COLOR_CODE_SUFFIX}"
}

element_in_array () {
  local e match="$1"; shift;
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}
