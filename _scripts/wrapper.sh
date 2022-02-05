#!/bin/bash

wrapper() {
    ## Run a native command if it's available, otherwise from a docker image
    ## (Note: this only works with programs that read/write to stdin/stdout.
    ## Reading and writing files on the client host system is not supported.)
    DOCKER=${DOCKER:-docker}
    command=$1; shift
    WRAPPER_IMAGE=localhost/wrapper_${command}
    if which ${command} >/dev/null 2>&1; then
        ## Runs the native command passing args and stdin, prefixed with
        ## "command" to ignore the function with the same name:
        command ${command} "${@}" </dev/stdin
    else
        ${DOCKER} run --rm -i ${WRAPPER_IMAGE} ${command} "${@}" </dev/stdin
    fi
}

wrapper_build() {
    DOCKER=${DOCKER:-docker}
    dockerfile=$(</dev/stdin)
    command=$1; shift
    WRAPPER_IMAGE=localhost/wrapper_${command}
    if ! which ${command} >/dev/null 2>&1; then
        echo "${dockerfile}" | ${DOCKER} build -t ${WRAPPER_IMAGE} - 2>&1 >/dev/null
    fi
}


### USAGE:
# source wrapper.sh
# jq() {
#     cat <<EOF | wrapper_build jq
# FROM alpine
# RUN apk add -U jq
# EOF
#     wrapper jq ${@} </dev/stdin
# }
#
# ## Then use jq like normal, whether its installed or not:
# cat passwords.json | jq
