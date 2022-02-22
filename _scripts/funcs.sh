#!/bin/bash

BIN=$(dirname ${BASH_SOURCE})

fault(){ test -n "$1" && echo $1; echo "Exiting." >/dev/stderr ; exit 1; }
check_var(){
    __missing=false
    __vars="$@"
    for __var in ${__vars}; do
        if [[ -z "${!__var}" ]]; then
            echo "${__var} variable is missing." >/dev/stderr
            __missing=true
        fi
    done
    if [[ ${__missing} == true ]]; then
        fault
    fi
}

ask() {
    __prompt=${1}; __var=${2}; __default=${3}
    read -p "${__prompt}"$'\x0a: ' -i "${__default}" ${__var}
    export ${__var}
}

require_input() {
    ## require_input {PROMPT} {VAR} {DEFAULT}
    ## Read variable, set default if blank, error if still blank
    test -z ${3} && dflt="" || dflt=" (${3})"
    read -p "$1$dflt: " $2
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
        ${BIN}/dotenv -f ${ENV_FILE} ROOT_DOMAIN
    else
        echo "Could not find $(abspath ${ENV_FILE})"
        fault "Run `make config` in the root project directory first."
    fi
}
