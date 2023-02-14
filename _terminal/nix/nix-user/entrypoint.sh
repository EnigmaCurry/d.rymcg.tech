#!/bin/bash

set -e

NIX_HOMEMANAGER_HOME="${NIX_HOMEMANAGER_HOME:-nix-user.nix}"
NIX_GIT_CLONE="${NIX_GIT_CLONE:-${HOME}/git/vendor/enigmacurry/d.rymcg.tech}"
NIX_GIT_REPO="${NIX_GIT_REPO:-https://github.com/EnigmaCurry/d.rymcg.tech.git}"
NIX_GIT_BRANCH="${NIX_GIT_BRANCH}"

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

check_var NIX_HOMEMANAGER_HOME NIX_GIT_CLONE NIX_GIT_REPO

if [[ ! -e "${NIX_GIT_CLONE}" ]]; then
    git clone "${NIX_GIT_REPO}" "${NIX_GIT_CLONE}"
    if [[ -n "${NIX_GIT_BRANCH}" ]]; then
        git checkout "${NIX_GIT_BRANCH}"
    fi
fi

(set -x; home-manager switch)

if [[ ! -f .ssh/id_rsa ]]; then
    ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa <<<y >/dev/null 2>&1
fi

if [[ ! -f .ssh/config ]]; then
    cat <<EOF > .ssh/config
Host ${NIX_DOCKER_SSH_HOST}
    User ${NIX_DOCKER_SSH_USER}
    Port ${NIX_DOCKER_SSH_PORT}
    ControlMaster auto
    ControlPersist yes
    ControlPath /tmp/ssh-%u-%r@%h:%p
EOF
    ssh-keyscan -p ${NIX_DOCKER_SSH_PORT} ${NIX_DOCKER_SSH_HOST} >> .ssh/known_hosts
    docker context create ${NIX_DOCKER_SSH_HOST} --docker "host=ssh://${NIX_DOCKER_SSH_HOST}"
    docker context use ${NIX_DOCKER_SSH_HOST}
fi

echo "## Sleeping forever ... "
/bin/sh -c 'while true; do sleep 3; done;'
