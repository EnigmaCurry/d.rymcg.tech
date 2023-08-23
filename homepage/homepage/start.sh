#!/bin/bash

## Pull domain from HOMEPAGE_TEMPLATE_REPO:
## HOMEPAGE_TEMPLATE_REPO can be in 1 of 2 formats:
## 1) git@github.com:YourUsername/my-private-homepage-template.git
## 2) https://github.com/EnigmaCurry/d.rymcg.tech_homepage-template.git
## Deploy Keys are only needed for format 1.
REPO_DOMAIN=$(echo "${HOMEPAGE_TEMPLATE_REPO}" | grep -oP '(?<=@)([^\/:]+)' | sed 's/[^@]*@//')
## If HOMEPAGE_TEMPLATE_REPO is in format 1:
if [[ ! -z "${REPO_DOMAIN}" ]]; then
    ## Create git SSH key
    SSH_DIR="/app/config/ssh"
    SSH_KEYFILE="${SSH_DIR}/id_rsa"
    SSH_KNOWNHOSTS_FILE="${SSH_DIR}/known_hosts"
    test -f "${SSH_KEYFILE}" && export GIT_SSH_COMMAND="ssh -i '${SSH_KEYFILE}' -o UserKnownHostsFile='${SSH_KNOWNHOSTS_FILE}'"

    ## Add known SSH host keys:
    mkdir -p ${SSH_DIR}
    touch "${SSH_KNOWNHOSTS_FILE}"
    ## Pull custom port from HOMEPAGE_TEMPLATE_REPO:
    REPO_PORT=$(echo "${HOMEPAGE_TEMPLATE_REPO}" | grep -oP '(?<=:)\d+')
    ## known_hosts lists hostnames differently when the server uses a custom port. 
    if [[ ! -z "${REPO_PORT}" ]]; then
        GREP_REPO="[${REPO_DOMAIN}]:${REPO_PORT}"
    else
        GREP_REPO="${REPO_DOMAIN}"
    fi
    if ! grep -F "${GREP_REPO}" "${SSH_KNOWNHOSTS_FILE}" > /dev/null
    then
        ## ssh-keyscan returns a commented line (begins with #) for each result, we don't want that line
        ssh-keyscan -t rsa -p "${REPO_PORT:-22}" "${REPO_DOMAIN}" | grep -v '^#' >> "${SSH_KNOWNHOSTS_FILE}"
    fi
fi

## Clone the user supplied template repository if supplied:
if [[ -n "${HOMEPAGE_TEMPLATE_REPO}" ]]; then
    if ls /app/config/*.yaml >/dev/null 2>&1 && [[ "${HOMEPAGE_TEMPLATE_REPO_SYNC_ON_START}" != "true" ]]; then
        echo "Found existing config files in /app/config, so skipping HOMEPAGE_TEMPLATE_REPO sync"
        echo "(Set HOMEPAGE_TEMPLATE_REPO_SYNC_ON_START=true to force syncing)"
    else
        echo "Cloning personal template repository: ${HOMEPAGE_TEMPLATE_REPO}"
        TMP_CLONE=$(mktemp -d)
        git clone --depth 1 ${HOMEPAGE_TEMPLATE_REPO} ${TMP_CLONE}
        if [[ $? == 0 ]]; then
            rm -rf /app/config/*.yaml
            for file in ${TMP_CLONE}/*.yaml; do
                out_path="/app/config/$(basename $file)"
                cat "${file}" | envsubst > $out_path
                echo "Rendered template file: $out_path"
            done
            rm -rf ${TMP_CLONE}/.* && rm ${TMP_CLONE}/Dockerfile && rm ${TMP_CLONE}/*.yaml
            mv ${TMP_CLONE}/* /app/config/

            rm -rf ${TMP_CLONE}
        else
            echo "ERROR: Could not clone from git repository: ${HOMEPAGE_TEMPLATE_REPO}"
        fi
    fi
fi

## Start reloader webhook in the background:
node /app/reloader/webhook_reloader.js &

## Start homepage service in the foreground:
node /app/server.js
