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

echo "## Cloning ${NIX_GIT_REPO} ..."
if [[ ! -e "${NIX_GIT_CLONE}" ]]; then
    git clone "${NIX_GIT_REPO}" "${NIX_GIT_CLONE}"
    if [[ -n "${NIX_GIT_BRANCH}" ]]; then
        git checkout "${NIX_GIT_BRANCH}"
    fi
fi

if [[ -e .config/nixpkgs/home.nix ]]; then
    fault "Error: Found an existing .config/nixpkgs/home.nix - you should not create a home.nix, but set NIX_HOMEMANAGER_HOME environment variable, and set it to the name of a file with a different name, and a symlink will be created to home.nix at startup."
fi

ln -s ${HOME}/.config/nixpkgs/${NIX_HOMEMANAGER_HOME} ${HOME}/.config/nixpkgs/home.nix

(set -x; home-manager switch)

echo "## Sleeping forever ... "
/bin/sh -c 'while true; do sleep 3; done;'
