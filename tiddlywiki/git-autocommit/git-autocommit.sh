#!/bin/bash

echo "# git-autocommit entrypoint args: $@"
echo ""

BACKUP_FILE=${BACKUP_FILE:-/www/index.html}
SSH_KEYFILE=${SSH_KEYFILE:-${HOME}/.ssh/id_rsa}
GIT_ROOT=${GIT_ROOT:-/git}
GIT_BACKUP_REPO=${GIT_BACKUP_REPO}
GIT_BACKUP_SSH_DOMAIN=${GIT_BACKUP_SSH_DOMAIN:-$(echo ${GIT_BACKUP_REPO} | cut -d "@" -f2 | cut -d ":" -f 1)}
GIT_BACKUP_BRANCH=${GIT_BACKUP_BRANCH:-master}
GIT_BACKUP_AUTHOR=${GIT_BACKUP_AUTHOR:-TiddlyWiki Autocommit Bot}
GIT_BACKUP_EMAIL=${GIT_BACKUP_EMAIL:-bot@example.com}
GIT_BACKUP_NAME=${GIT_BACKUP_NAME:-tiddlywiki-backup.html}
INOTIFY_TIMEOUT=${INOTIFY_TIMEOUT:-600}
CMD=$1; shift

check_var(){
    __missing=false
    __vars="$@"
    for __var in ${__vars}; do
        if [[ -z "${!__var}" ]]; then
            echo "${__var} is required, but it's blank." >/dev/stderr
            __missing=true
        fi
    done
    if [[ ${__missing} == true ]]; then
        return 1
    fi
}

set -e

if [[ "$#" -gt 0 ]]; then echo "Error: too many arguments."; exit 1; fi
check_var BACKUP_FILE SSH_KEYFILE GIT_ROOT GIT_BACKUP_REPO \
          GIT_BACKUP_BRANCH GIT_BACKUP_AUTHOR \
          GIT_BACKUP_EMAIL GIT_BACKUP_NAME INOTIFY_TIMEOUT
check_var GIT_BACKUP_SSH_DOMAIN

if [ ! -f ${SSH_KEYFILE} ]; then
    ssh-keygen -t rsa -P "" -f ${SSH_KEYFILE}
    ssh-keyscan ${GIT_BACKUP_SSH_DOMAIN} > ${HOME}/.ssh/known_hosts
    echo "## Generated new SSH key (${SSH_KEYFILE})"
else
    echo "## Found existing SSH pubkey (${SSH_KEYFILE})"
fi
echo ""
echo "## Copy this SSH pubkey to your git forge authorized_keys (deploy key):"
ssh-keygen -y -f ${SSH_KEYFILE}
echo ""
echo "## The SSH fingerprint is:"
echo ""
ssh-keygen -l -f ${SSH_KEYFILE}


if [ "${CMD}" == "ssh-keygen" ]; then
    echo "## ssh-keygen complete"
    exit 0
fi

set -x

git config --global user.email "${GIT_BACKUP_EMAIL}"
git config --global user.name "${GIT_BACKUP_AUTHOR}"
git config --global pull.rebase false

if [ ! -d ${GIT_ROOT}/.git ]; then
    git clone ${GIT_BACKUP_REPO} ${GIT_ROOT}
fi

cd ${GIT_ROOT}
git checkout ${GIT_BACKUP_BRANCH} || git checkout --orphan ${GIT_BACKUP_BRANCH}

NUM_COMMITS=$(git rev-list --count HEAD || echo 0)
if [[ "${NUM_COMMITS}" == "0" ]]; then
    cp ${BACKUP_FILE} ${GIT_BACKUP_NAME}
    git add ${GIT_BACKUP_NAME}
    git commit -m "initial commit"
fi

git pull origin ${GIT_BACKUP_BRANCH} || true
git push -u origin ${GIT_BACKUP_BRANCH}

set +ex
while true; do
    echo "## $(date) :: Waiting for changes (timeout=${INOTIFY_TIMEOUT}) ..."
    inotifywait -qq --timeout ${INOTIFY_TIMEOUT} -e CLOSE_WRITE ${BACKUP_FILE} 2>/dev/null
    if [ $? -eq 0 ]; then
	    # File change detected
	    sleep 1
	elif [ $? -eq 1 ]; then
	    # inotify error occured?
        sleep 1
	elif [ $? -eq 2 ]; then
	    # Do the sync now even though no changes were detected:
        sleep 1
    else
        continue
	fi
    (
        echo "## $(date) :: Running backup now ..."
        git pull origin ${GIT_BACKUP_BRANCH}
        cp ${BACKUP_FILE} ${GIT_ROOT}/${GIT_BACKUP_NAME}
        git add ${GIT_BACKUP_NAME}
        [ "$(git diff --staged)" != "" ] && git commit -m "${GIT_BACKUP_NAME} :: $(date)" && git push
    )
done
