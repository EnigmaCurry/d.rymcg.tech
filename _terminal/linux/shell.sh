#!/bin/bash
## Linux Shell Containers:
shell_container() {
    (
        ## Remember the path of the directory containing this script:
        SRC_DIR=$(realpath $(dirname ${BASH_SOURCE}))

        ## Make substitutes for conflicting global variable names:
        declare -A ARG_SUBSTITUTES
        ARG_SUBSTITUTES=([USER]=USERNAME [HOSTNAME]=NAME)

        ## Set uppercase environment vars from ignored case arg=value arguments:
        for var in "$@"; do
            parts=(${var//=/ }); var=${parts[0]}; val=${parts[@]:1};
            if [[ ${#parts[@]} == 1 ]]; then break; fi
            shift
            escaped_val=$(printf '%s\n' "${val}" | sed -e 's/[\/&]/\\&/g')
            if [[ -n ${ARG_SUBSTITUTES[${var^^}]} ]]; then
                var=${ARG_SUBSTITUTES[${var^^}]}
            fi
            export ${var^^}="${escaped_val}"
        done

        MAKE_TARGET=shell
        ## Process alternative commands that start with "--":
        if [[ $1 == --* ]]; then
            if [[ $1 == "--rm" ]] || [[ $1 == "--destroy" ]]; then
                MAKE_TARGET=destroy
                shift
            else
                echo "Invalid argument: $1"
                exit 1
            fi
        fi

        ## Treat any remaining argument as the hostname or username@hostname:
        parts=(${1//@/ });
        if [[ ${#parts[@]} == 2 ]]; then
            export USERNAME=${parts[0]}
            export NAME=${parts[1]}
            shift
        elif [[ -n ${1} ]]; then
            export NAME=$1
            shift
        fi

        ## Assert there should be no more arguments:
        if [[ -n ${1} ]]; then
            echo "Invalid argument: $1"
            exit 1
        fi

        ## Run the Makefile:
        make -C ${SRC_DIR} ${MAKE_TARGET}
    )
}

shell_container_list() {
    make -C $(realpath $(dirname ${BASH_SOURCE})) list
}

## Only runs this part if the script is being run directly:
## This part will not run if the script is being sourced:
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    shell $@
fi
