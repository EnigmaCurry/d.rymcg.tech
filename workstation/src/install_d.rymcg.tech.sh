#!/bin/bash
set -ex
GIT_REPO=https://github.com/EnigmaCurry/d.rymcg.tech.git
GIT_BRANCH=master
ROOT_DIR=${HOME}/git/vendor/enigmacurry/d.rymcg.tech

DEBIAN_FRONTEND=noninteractive sudo apt-get update
DEBIAN_FRONTEND=noninteractive sudo apt-get install -y git openssl apache2-utils xdg-utils jq sshfs bsdextrautils docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

if ! test -e ${ROOT_DIR}; then
    echo "Cloning ${GIT_REPO} ..."
    git clone ${GIT_REPO} ${ROOT_DIR}
    cd ${ROOT_DIR}
    git checkout ${GIT_BRANCH}
else
    echo "${ROOT_DIR} already exists so I'm *not* going to clone it from ${GIT_REPO}"
fi
