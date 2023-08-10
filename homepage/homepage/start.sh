#!/bin/bash

## Create git SSH key
SSH_DIR="/app/config/ssh"
SSH_KEYFILE="${SSH_DIR}/id_rsa"
SSH_KNOWNHOSTS_FILE="${SSH_DIR}/known_hosts"
test -f "${SSH_KEYFILE}" && export GIT_SSH_COMMAND="ssh -i '${SSH_KEYFILE}' -o UserKnownHostsFile='${SSH_KNOWNHOSTS_FILE}'"

## Add known SSH host keys:
touch "${SSH_KNOWNHOSTS_FILE}"
if ! grep github.com "${SSH_KNOWNHOSTS_FILE}" > /dev/null
then
     echo "github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=" >> "${SSH_KNOWNHOSTS_FILE}"
fi
REPO_DOMAIN=$(echo "${HOMEPAGE_TEMPLATE_REPO}" | grep -oP '(?<=@|:\/\/)([^\/:]+)' | sed 's/[^@]*@//')
REPO_PORT=$(echo "${HOMEPAGE_TEMPLATE_REPO}" | grep -oP '(?<=:)\d+') || 22
if ! grep "[$( echo ${REPO_DOMAIN} | sed 's/\./\\./g' )]:${REPO_PORT}" "${SSH_KNOWNHOSTS_FILE}" > /dev/null
then
    ssh-keyscan -t rsa -p "${REPO_PORT}" "${REPO_DOMAIN}" 2>/dev/null | grep -v '^#' >> "${SSH_KNOWNHOSTS_FILE}"
fi

## Clone the user supplied template repository if supplied:
if [[ -n "${HOMEPAGE_TEMPLATE_REPO}" ]]; then
    if ls /app/config/*.yaml >/dev/null && [[ "${HOMEPAGE_TEMPLATE_REPO_SYNC_ON_START}" != "true" ]]; then
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
