#!/bin/bash

BIN=$(dirname ${BASH_SOURCE})
ROOT_DIR=${ROOT_DIR:-$(dirname ${BIN})}

stderr(){ echo "$@" >/dev/stderr; }
error(){ stderr "Error: $@"; }
fault(){ test -n "$1" && error $1; stderr "Exiting."; exit 1; }
cancel(){ stderr "Canceled."; exit 2; }
exe() { (set -x; "$@"); }
print_array(){ printf '%s\n' "$@"; }
trim_trailing_whitespace() { sed -e 's/[[:space:]]*$//'; }
trim_leading_whitespace() { sed -e 's/^[[:space:]]*//'; }
trim_whitespace() { trim_leading_whitespace | trim_trailing_whitespace; }
wizard() { ${BIN}/script-wizard "$@"; }
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

debug_var() {
    local var=$1
    check_var var
    stderr "## DEBUG: ${var}=${!var}"
}

debug_array() {
    local -n ary=$1
    echo "## DEBUG: Array '$1' contains:"
    for i in "${!ary[@]}"; do
        echo "## ${i} = ${ary[$i]}"
    done
}

pop_array() {
    # Pop off the first element of an array and save it to a variable:
    local -n __arr=$1       # Bind to array
    local out_var=$2      # Variable name to store output
    local first_element="${__arr[0]}"
    __arr=("${__arr[@]:1}")   # Remove the first element

    if [[ -n "$first_element" ]]; then
        eval "$out_var=\"$first_element\""
    else
        eval "unset $out_var"
        return 1
    fi
}

ask() {
    ## Ask the user a question and set the given variable name with their answer
    local __prompt="${1}"; local __var="${2}"; local __default="${3}"
    read -e -p "${__prompt}"$'\x0a: ' -i "${__default}" ${__var}
    export ${__var}
}

ask_no_blank() {
    ## Ask the user a question and set the given variable name with their answer
    ## If the answer is blank, repeat the question.
    local __prompt="${1}"; local __var="${2}"; local __default="${3}"
    while true; do
        read -e -p "${__prompt}"$'\x0a: ' -i "${__default}" ${__var}
        export ${__var}
        [[ -z "${!__var}" ]] || break
    done
}

ask_echo() {
    ## Ask the user a question then print the non-blank answer to stdout
    (
        prompt=$1; shift
        ask_no_blank "$prompt" ASK_ECHO_VARNAME $@ >/dev/stderr
        echo "${ASK_ECHO_VARNAME}"
    )
}

ask_echo_blank() {
    ## Ask the user a question, allowing blank responses, then print the answer to stdout
    (
        prompt=$1; shift
        ask "$prompt" ASK_ECHO_VARNAME $@ >/dev/stderr
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

make_var_name() {
    # Make an environment variable out of any string
    # Replaces all invalid characters with a single _
    echo "$@" | sed -e 's/  */_/g' -e 's/--*/_/g' -e 's/[^a-zA-Z0-9_]/_/g' -e 's/__*/_/g' -e 's/.*/\U&/' -e 's/__*$//' -e 's/^__*//'
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

dotenv_get() {
    VAR=$1; shift
    check_var ENV_FILE VAR
    if [[ ! -f ${ENV_FILE} ]]; then
        fault "Missing ENV_FILE :: ${ENV_FILE}"
    else
        VAL="$(${BIN}/dotenv -f ${ENV_FILE} get ${VAR})"
        # Check if the first and last characters are double quotes
        if [[ ${VAL:0:1} == "\"" && ${VAL: -1} == "\"" ]]; then
            # Remove the first and last character (the double quotes)
            VAL="${VAL:1:${#VAL}-2}"
        fi
        check_var VAL
        echo "${VAL}"
        #stderr "## dotenv_get ${VAR}=${VAL}"
    fi    
}

docker_compose() {
    local ENV_FILE=${ENV_FILE:-.env_$(${BIN}/docker_context)}
    local PROJECT_NAME="$(basename "$PWD")"
    if [[ -n "${instance:-${INSTANCE}}" ]] && [[ "${ENV_FILE}" != ".env_${DOCKER_CONTEXT}_${instance:-${INSTANCE}}" ]]; then
        ENV_FILE="${ENV_FILE}_${instance:-${INSTANCE}}"
        PROJECT_NAME="$(basename "$PWD")_${instance:-${INSTANCE}}"
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

docker_ssh() {
    SSH_HOST=$(docker context inspect --format '{{.Endpoints.docker.Host}}' | sed 's|ssh://||')
    check_var SSH_HOST
    (set -x; ssh ${SSH_HOST} $@)
}

ytt() {
    set -e
    local IMAGE=localhost/ytt
    docker image inspect ${IMAGE} >/dev/null || docker build -t ${IMAGE} -f- . >/dev/null <<'EOF'
FROM debian:stable-slim AS ytt
ARG YTT_VERSION=v0.44.3
RUN apt-get update && apt-get install -y wget && wget "https://github.com/vmware-tanzu/carvel-ytt/releases/download/${YTT_VERSION}/ytt-linux-$(dpkg --print-architecture)" -O ytt && install ytt /usr/local/bin/ytt
EOF
    non_template_commands_pattern="(help|completion|fmt|version)"
    if [[ "$@" == "" ]]; then
        CMD="docker run --rm -i ${IMAGE} ytt help"
    elif [[ "$1" =~ $non_template_commands_pattern ]]; then
        CMD="docker run --rm -i ${IMAGE} ytt ${@}"
    else
        CMD="docker run --rm -i ${IMAGE} ytt -f- ${@}"
    fi
    eval $CMD
}

yq() {
    set -e
    local IMAGE=localhost/yq
    docker image inspect ${IMAGE} >/dev/null || docker build -t ${IMAGE} -f- . >/dev/null <<'EOF'
FROM debian:stable-slim AS yq
RUN apt-get update && apt-get install -y yq
EOF
    docker run --rm -i "${IMAGE}" yq "${@}"
}

read_stdin_or_args() {
    # Read from stdin or args but not both:
    if [ -t 0 ]; then
        # Reading from command line arguments:
        if [[ $# -lt 1 ]]; then
            fault "No input given"
        fi        
        echo "$@"
    else
        if [[ $# -gt 0 ]]; then
            fault "Cannot process stdin and command arguments at the same time"
        fi        
        cat
    fi
}

yaml_to_json() {
    read_stdin_or_args "$@" | yq -j -c
}

json_to_yaml() {
    read_stdin_or_args "$@" | yq -y
}

array_to_json() {
    # array_to_json "${THINGS[@]}"
    printf '%s\n' "$@" | jq -R . | jq -c -s .
}

array_join() {
    # array_join "," "${THINGS[@]}"
    local join=$1; shift
    array_to_json "$@" | jq -r "join(\"${join}\")"
}

volume_rsync() {
    if [[ $# -lt 2 ]]; then
        fault "Usage: volume_rsync VOLUME ARGS..."
    else
        local VOLUME="${1}"; shift
        check_var VOLUME
    fi
    # Check that the localhost/rsync image exists, if not build it:
    docker image inspect localhost/rsync >/dev/null || docker build -t localhost/rsync ${ROOT_DIR}/_terminal/rsync
    if [[ "${DISABLE_VOLUME_RSYNC_CHECKS}" != "true" ]]; then
        echo "Doing initial rsync checks for volume: ${VOLUME} ..."
        # Check that the volume we will sync to already exists:
        if ! docker volume inspect "${VOLUME}" >/dev/null; then
            fault "You must create the '${VOLUME}' volume before running this."
        fi
    fi
    echo "Syncing ..."
    TIMEFORMAT='total time: %2Rs'
    time rsync --rsh="docker run -i --rm -v ${VOLUME}:/data -w /data localhost/rsync" "$@"
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

colorize() {
    ## Highlight text patterns in stdin with ANSI color
    set -e
    if [[ $# -lt 2 ]]; then
        fault "Not enough args: expected COLOR and PATTERN arguments"
    fi
    local COLOR=$1; shift
    local PATTERN=$1; shift
    check_var COLOR PATTERN
    case "${COLOR}" in
        "black") COLOR=30;;
        "red") COLOR=31;;
        "green") COLOR=32;;
        "brown") COLOR=33;;
        "orange") COLOR=33;;
        "blue") COLOR=34;;
        "purple") COLOR=35;;
        "cyan") COLOR=36;;
        "white") COLOR=37;;
        *) fault "Unknown color"
    esac
    PATTERN='^.*'"${PATTERN}"'.*$|'
    readarray stdin
    echo "${stdin[@]}" | \
        GREP_COLORS="mt=01;${COLOR}" grep --color -E "${PATTERN}"
}

element_in_array () {
  local e match="$1"; shift;
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

gen_password() {
    set -eo pipefail
    LENGTH=${1:-30}
    openssl rand -base64 ${LENGTH} | tr '=' '0' | tr '+' '0' | tr '/' '0' | tr '\n' '0' | head -c ${LENGTH}
}

version_spec() {
    ## Check the lock file to see if the apps INSTALLED_VERSION is ok
    # version_spec APP_NAME INSTALLED_VERSION
    set -eo pipefail
    # The name of the app:
    local APP=$1;
    check_var APP
    # The installed version to check against the lock file version, could be blank:
    local CHECK_VERSION=$2;
    local VERSION_LOCK="${ROOT_DIR}/.tools.lock.json"
    if [[ ! -f "$VERSION_LOCK" ]]; then
        fault "The version lock spec file is missing: ${VERSION_LOCK}"
    fi
    # Grab the locked version of APP from the lock file:
    local LOCKED_VERSION=$(jq -r ".dependencies.\"${APP}\"" ${ROOT_DIR}/.tools.lock.json)
    (test -z "${LOCKED_VERSION}" || test "${LOCKED_VERSION}" == "null") && fault "The app '${APP}' is not listed in ${VERSION_LOCK}"

    # Return the locked version string:
    echo ${LOCKED_VERSION}

    # But error if the installed version is different than the locked version:
    if [[ -n "${CHECK_VERSION}" ]] && [[ "${VERSION}" != "${CHECK_VERSION}" ]]; then
        fault "Installed ${APP} version ${CHECK_VERSION} does not match the locked version: ${LOCKED_VERSION}"
    fi
}

text_centered() {
    local columns="$1"
    check_var columns
    shift
    local text="$@"
    check_var text
    printf "%*s\n" $(( (${#text} + columns) / 2)) "$text"
}

text_centered_full() {
    local columns="$(tput cols)"
    text_centered ${columns} "$@"
}

text_centered_wrap() {
    local wrap="$1"
    check_var wrap
    shift;
    local wrap_rev="${wrap}"
    wrap_rev=$(text_reverse "${wrap}")
    local columns="$1"
    check_var columns
    shift;
    local wrap_length=${#wrap}
    local text="$@"
    check_var text
    centered_text=$(text_centered "${columns}" "${text}")
    trailing_whitespace=$(text_repeat $((${#centered_text}-${#text})) " ")
    whitespace_offset=${wrap_length}
    new_text="${wrap}${centered_text:${#wrap}}${trailing_whitespace:${whitespace_offset}}${wrap}"
    if [[ $((wrap_length%2)) -eq 0 ]] && [[ $((${#new_text}%2)) -eq 1 ]]; then
        whitespace_offset=$((whitespace_offset-1))
    elif [[ $((wrap_length%2)) -eq 1 ]] && [[ $((${#new_text}%2)) -eq 1 ]]; then
        whitespace_offset=$((whitespace_offset-1))
    fi
    new_text="${wrap}${centered_text:${#wrap}}${trailing_whitespace:${whitespace_offset}}${wrap_rev}"
    echo "${new_text}"
}

text_repeat() {
    local repeat="$1"
    check_var repeat
    shift
    local text="$*"
    check_var text
    readarray -t repeated < <(yes "${text}" 2>/dev/null | head -n ${repeat})
    printf "%s" "${repeated[@]}"
    echo
}

text_reverse() {
    local text="$@"
    check_var text
    for((i=${#text}-1;i>=0;i--)); do rev="$rev${text:$i:1}"; done
    echo "${rev}"
}

text_mirror() {
    local text="$@"
    check_var text
    rev=$(text_reverse "${text}")
    echo "${text}${rev}"
}

text_line() {
    # Fill a line of the target width with a repeating pattern
    # If width is 0, fill the entire line.
    local width="$1";
    local pattern="$2";
    check_var width
    shift 2
    if [[ "${width}" == "0" ]]; then
        width="$(tput cols)"
    fi
    local pattern_length="${#pattern}"
    text_repeat $((width/pattern_length)) "${pattern}"
    if [[ "$#" -gt 0 ]]; then
        echo "$(text_centered "$*")"
        text_repeat $((width/pattern_length)) "${pattern}"
    fi
}

separator() {
    local pattern="$1"
    check_var pattern
    shift
    local width="$1"
    check_var width
    shift
    if [[ "${width}" == "0" ]]; then
        width="$(tput cols)"
    fi
    local text="$@"
    echo
    local sep=$(text_line ${width} "${pattern}")
    local index_half=$((${#sep}/2))
    sep="${sep:0:${index_half}}"
    sep=$(text_mirror "${sep}")
    local columns="${#sep}"
    echo "${sep}"
    if [[ -n "${text}" ]]; then
        text_centered_wrap "${pattern}" "${columns}" "${text}"
        echo "${sep}"
    fi
    echo
}

parse_vars_from_env_file() {
    local f=$1
    check_var f
    grep -oP "^[a-zA-Z_0-9]+=" ${f} | sed 's/=//'
}

get_all_projects() {
    ROOT_DIR=$(realpath ${BIN}/..)
    find "${ROOT_DIR}" -maxdepth 1 -type d -printf "%P\n" | grep -v "^_" | grep -v "^\." | sort -u | xargs -iXX /bin/bash -c "test -f ${ROOT_DIR}/XX/Makefile && echo XX"
}

wait_until_healthy() {
    echo "Waiting until all services are started and become healthy ..."
    local containers=()
    PROJECT_NAME=$1
    shift

    while IFS= read -r CONTAINER_ID; do
        local inspect_json=$(docker inspect ${CONTAINER_ID})
        local name=$(echo "${inspect_json}" | jq -r ".[0].Name" | sed 's|^/||')
        if [[ "${name}" != "${PROJECT_NAME}-config-1" ]]; then containers+=("$name"); fi
    done <<< "$@"
    local attempts=0
    while true; do
        attempts=$((attempts+1))
        if [[ "${#containers}" == "0" ]]; then
            break
        fi
        local random_container=$(random_element "${containers[@]}")
        if [[ -z "${random_container}" ]]; then
            continue
        fi
        local inspect_json=$(docker inspect ${random_container})
        local name=$(echo "${inspect_json}" | jq -r ".[0].Name" | sed 's|^/||')
        local status=$(echo "${inspect_json}" | jq -r ".[0].State.Status")
        local health=$(echo "${inspect_json}" | jq -r ".[0].State.Health.Status")
        if [[ "$status" == "running" ]] && ([[ "$health" == "healthy" ]] || [[ "$health" == "null" ]]); then
            containers=( "${containers[@]/${name}}" )
            if [[ "${#containers}" == "0" ]]; then
                break
            elif [[ "${attempts}" -gt 15 ]]; then
                echo "Still waiting for services to finish starting: ${containers[@]}"
            fi
        fi

        if [[ "${attempts}" -gt 150 ]]; then
            fault "Gave up waiting for services to start."
        fi
        if [[ "$((attempts%5))" == 0 ]]; then
            echo "Still waiting for services to finish starting: ${containers[@]}"
        fi
        sleep 2
    done
    echo "All services healthy."
}

random_element() {
    local arr=("$@")
    if [[ "${#@}" -lt 1 ]]; then
        fault "Need more args"
    fi
    echo "${arr[ $RANDOM % ${#arr[@]} ]}"
}

confirm() {
    ## Confirm with the user.
    ## Check env for the var YES, if it equals "yes" then bypass this confirm.
    ## This version depends on `script-wizard` being installed.
    test ${YES:-no} == "yes" && exit 0

    local default=$1; local prompt=$2; local question=${3:-". Proceed?"}

    check_var default prompt question

    if [[ -f ${BIN}/script-wizard ]]; then
        ## Check if script-wizard is installed, and prefer to use that:
        local exit_code=0
        if [[ $default == "y" || $default == "true" ]]; then
            default="yes"
        elif [[ $default == "n" || $default == "false" ]]; then
            default="no"
        fi
        wizard confirm --cancel-code=2 "$prompt$question" "$default" && exit_code=$? || exit_code=$?
        if [[ "${exit_code}" == "2" ]]; then
            cancel
        fi
        return ${exit_code}
    else
        ## Otherwise use a pure bash version:
        if [[ $default == "y" || $default == "yes" || $default == "true" ]]; then
            dflt="Y/n"
        else
            dflt="y/N"
        fi

        read -e -p "${prompt}${question} (${dflt}): " answer
        answer=${answer:-${default}}

        if [[ ${answer,,} == "y" || ${answer,,} == "yes" || ${answer,,} == "true" ]]; then
            return 0
        else
            return 1
        fi
    fi
}

choose() {
    local exit_code=0
    wizard choose --cancel-code=2 "$@" && exit_code=$? || exit_code=$?
    if [[ "${exit_code}" == "2" ]]; then
        cancel
    fi
    return ${exit_code}
}

select_wizard() {
    local exit_code=0
    wizard select --cancel-code=2 "$@" && exit_code=$? || exit_code=$?
    if [[ "${exit_code}" == "2" ]]; then
        cancel
    fi
    return ${exit_code}
}

netmask_to_prefix() {
    #thanks agc https://stackoverflow.com/a/50419919
    c=0 x=0$( printf '%o' ${1//./ } )
    while [ $x -gt 0 ]; do
        let c+=$((x%2)) 'x>>=1'
    done
    echo $c ;
}

prefix_to_netmask () {
    #thanks https://forum.archive.openwrt.org/viewtopic.php?id=47986&p=1#p220781
    set -- $(( 5 - ($1 / 8) )) 255 255 255 255 $(( (255 << (8 - ($1 % 8))) & 255 )) 0 0 0
    [ $1 -gt 1 ] && shift $1 || shift
    echo ${1-0}.${2-0}.${3-0}.${4-0}
}

validate_ip_address () {
    #thanks https://stackoverflow.com/a/21961938
    echo "$@" | grep -o -E '^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$' >/dev/null
}

validate_ip_network() {
    #thanks https://stackoverflow.com/a/21961938
    PREFIX=$(echo "$@" | grep -o -P "/\K[[:digit:]]+$")
    if [[ "${PREFIX}" -ge 0 ]] && [[ "${PREFIX}" -le 32 ]]; then
        echo "$@" | grep -o -E '^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)/[[:digit:]]+$' >/dev/null
    else
        return 1
    fi
}

select_docker_network_cidr() {
    PROMPT=${1:-Select multiple Docker networks}
    docker_networks=($(docker network ls --format '{{.Name}}' | grep -vE '^(host|none|bridge)$'))
    readarray -t selected_networks < <(wizard select "${PROMPT}" "${docker_networks[@]}")
    docker_network_cidrs=()
    for network in "${selected_networks[@]}"; do
        cidr=$(docker network inspect "$network" --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}')
        docker_network_cidrs+=("$cidr")
    done
    array_join "," "${docker_network_cidrs[@]}"
}

encode_newlines() {
    # Replace all newlines with literal \n
    local result=""
    while IFS= read -r line || [ -n "$line" ]; do
        result+="${line}\\n"
    done
    result="${result%\\n}"
    echo -n "$result"
}

decode_newlines() {
    # Replace all occurrences of \n with actual newlines
    local input="$1"
    echo -e "${input//\\n/$'\n'}"
}


launch_editor_for_response() {
    local tempfile=$(mktemp -p '' input_response.XXXXXXXX)
    local editor="${VISUAL:-${EDITOR:-nano}}"
    local PROMPT=$1
    local DEFAULT=$2
    cleanup_editor_temp_response() {
        rm -f "${tempfile}"
    }
    trap cleanup_editor_temp_response EXIT
    (
        echo -e -n "$(decode_newlines "${DEFAULT}")"
        echo
        echo
        if [[ -n "$1" ]]; then
            echo "# $(capitalize_sentence $1)"
        fi
        echo "# Enter your input above. When you are done, save this file and exit."
        if [[ -z "${VISUAL:-${EDITOR}}" ]]; then
            echo "# Warning: Your preferred EDITOR (or VISUAL) variable was not set."
            echo "# The \"nano\" editor was launched by default."
        fi
        echo "# To cancel this process, exit the editor or save a blank response."
        echo "# The leading and trailing whitespace will be trimmed."
        echo "# Lines beginning with '#' will be ignored."
    )  > "${tempfile}"
    echo "## Opening your preferred editor: ${editor}" >/dev/stderr
    $editor ${tempfile}
    local input=""
    while IFS= read -r line; do
        [[ $line =~ ^#.*$ ]] && continue  # Skip lines that start with '#'
        input+="${line}"$'\n'
    done < "${tempfile}"
    input="${input#"${input%%[![:space:]]*}"}"  # Remove leading whitespace
    input="${input%"${input##*[![:space:]]}"}"  # Remove trailing whitespace
    if [[ -z "${input}" ]]; then
        fault "No input provided."
    else
        echo "${input}"
    fi
    cleanup_editor_temp_response || return 0
}

capitalize_sentence() {
    local sentence="$*"
    # Capitalize the first character
    sentence="$(echo "${sentence:0:1}" | tr '[:lower:]' '[:upper:]')${sentence:1}"
    # Ensure the sentence ends with punctuation (., !, or ?)
    if [[ ! "$sentence" =~ [.!?]$ ]]; then
        sentence="${sentence}."
    fi
    echo "$sentence"
}
