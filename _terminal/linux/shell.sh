#!/bin/bash
shell_container() {
    (
        set -e
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

        ## TEMPLATE is a required argument:
        if [[ -z ${TEMPLATE} ]]; then
            echo "Missing required argument: TEMPLATE"
            exit 1
        fi

        ## Next optional argument is username@hostname
        ## that is, if the argument doesn't start with -- :
        if [[ $1 != --* ]]; then
            parts=(${1//@/ });
            if [[ ${#parts[@]} == 2 ]]; then
                ## got username@host
                export USERNAME=${parts[0]}
                export WORKDIR=/home/${USERNAME}
                export NAME=${parts[1]}
                shift
            elif [[ -n ${1} ]]; then
                ## got just host
                export NAME=$1
                shift
            fi
        fi
        
        if [[ $1 == *--help* ]]; then
            cat <<'EOF' | sed 's/::/\t/g' | expand -t 20
## Linux Shell Containers ::
## Run VM-like shell accounts in Docker or Podman containers.
## https://github.com/EnigmaCurry/d.rymcg.tech/tree/master/_terminal/linux
##
## shell_container (and all its aliases) accept Config arguments and/or Sub-commands:
##
## Config arguments (of the form: arg=value arg2=value2):
## (may be supplied lowercase arguments or UPPERCASE environment variables, see Examples.)
##
##   template :: The name of the Dockerfile template (eg. arch, debian, etc.)
##   name :: The hostname of the container (default: the same as the template name)
##   username :: The shell username inside the container (default: root)
##   entrypoint :: The shell command to start (default: `/bin/bash`, and fallback `/bin/sh`)
##   sudo :: If sudo=true give sudo privileges to the shell user (default: true)
##   network :: The name of the container network to join (default: shell-lan)
##   workdir :: The path of the working directory for the shell (default: /)
##   docker :: The name/path of the docker or podman executable (default: docker)
##   systemd :: If systemd=true, start systemd as PID1 (default: false)
##   sysbox :: If sysbox=true, run the container with the sysbox runtime (default: false)
##   shared_volume :: The name of the volume to share with the container (default: shell-shared)
##   shared_mount :: The mountpoint inside the container for the shared volume: (default: /shared)
##   dockerfile :: Override the path to the Dockerfile (default: images/Dockerfile.$TEMPLATE)
##   builddir :: Override the build context directory (default: directory containing shell.sh)
##   docker_args :: Adds additional docker run arguments (default: none)
##
## Notes:
##   'template' (or TEMPLATE env var) is the only required argument.
##   'name' may be given as the last argument omitting the 'name=' part
##   'username' and 'name' may be given together in the form 'username@name'

## Sub-commands (all start with -- , and must come after the Config arguments):
##   --help :: Shows this help screen
##   --build :: Build the template container image
##   --list :: List all the instances of this template
##   --start :: Start this instance without attaching
##   --start-all :: Start all the instances of this template
##   --stop :: Stop this instance
##   --stop-all :: Stop all the instances of this template
##   --restart :: Restart this instance
##   --restart-all :: Restart all the instances of this template
##   --prune :: Remove all stopped instances of this template
##   --rm  :: Remove (destroy) this instance
##   --rm-all :: Remove (destroy) all instances of this template

## Examples:
##   If the desired template is: arch
##   And the container name should be: shell_1
##   And the username to create is: foo

## Use the function directly, passing config as arguments:
shell_container template=arch foo@shell_1
## Or pass config as environment vars:
TEMPLATE=arch NAME=shell_1 USERNAME=foo shell_container

## Create a BASH alias for creating the arch template:
alias arch='shell_container template=arch'
## Use the alias without having to specify the template now:
arch foo@shell_1

## List all the instances of the arch template (running and stopped):
arch --list

## Stop a single instance:
arch --stop shell_1
## Or stop all the arch instances:
arch --stop-all

## Remove all stopped instances of the arch template:
arch --prune

## Did the help just scroll off the screen?
shell_container --help | less
EOF
            exit 1
        fi

        MAKE_TARGET=shell
        ## Process alternative commands that start with "--":
        if [[ $1 == --* ]]; then
            if [[ $1 == "--build" ]]; then
                MAKE_TARGET=build
                shift
            elif [[ $1 == "--list" ]] || [[ $1 == "--status" ]]; then
                MAKE_TARGET=list
                shift
            elif [[ $1 == "--start" ]]; then
                MAKE_TARGET=start
                shift
            elif [[ $1 == "--start-all" ]]; then
                MAKE_TARGET=start-all
                shift
            elif [[ $1 == "--stop" ]]; then
                MAKE_TARGET=stop
                shift
            elif [[ $1 == "--stop-all" ]]; then
                MAKE_TARGET=stop-all
                shift
            elif [[ $1 == "--restart" ]]; then
                MAKE_TARGET="stop start"
                shift
            elif [[ $1 == "--restart-all" ]]; then
                MAKE_TARGET="stop-all start-all"
                shift
            elif [[ $1 == "--prune" ]]; then
                MAKE_TARGET=prune
                shift
            elif [[ $1 == "--rm" ]] || [[ $1 == "--destroy" ]]; then
                MAKE_TARGET=destroy
                shift
            elif [[ $1 == "--rm-all" ]] || [[ $1 == "--destroy-all" ]]; then
                MAKE_TARGET=destroy-all
                shift
            else
                echo "Invalid argument: $1"
                exit 1
            fi
        fi

        ## Assert there should be no more arguments:
        if [[ -n ${1} ]]; then
            echo "Invalid argument: $1"
            exit 1
        fi

        ## If a username is specified, create the account first:
        if [[ $MAKE_TARGET == "shell" ]] && [[ -n ${USERNAME} ]]; then
            make --no-print-directory -C ${SRC_DIR} start create_user
        fi

        ## Run the Makefile:
        make --no-print-directory -C ${SRC_DIR} ${MAKE_TARGET}
    )
}

## Only runs this part if the script is being run directly (not being sourced):
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    shell_container $@
fi
