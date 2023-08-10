#!/bin/bash
## Create a new (system) user account and setup optional systemd linger.
## This script requires to be run as root.

set -e

SRC=$(dirname "${BASH_SOURCE}")
source ${SRC}/funcs.sh
check_var CREATE_USER # username to create
check_var CREATE_USER_LINGER # 'true' or 'false' to enable systemd linger for the user

if [[ ! -f /usr/bin/useradd ]]; then
    fault "This tool requires /usr/bin/useradd from shadow-utils - it looks like your system doesn't have that."
fi

if getent passwd | cut -d: -f1 | grep "^${CREATE_USER}$" >/dev/null; then

    fault "CREATE_USER '${CREATE_USER}' user already exists"
fi

if [[ "${UID}" != 0 ]]; then
    fault "This tool requires to be run as root."
fi

exe useradd -M "${CREATE_USER}"
CREATE_USER_HOME=$(getent passwd "${CREATE_USER}" | cut -d: -f6)
exe mkdir -p "${CREATE_USER_HOME}"
exe chown "${CREATE_USER}:${CREATE_USER}" "${CREATE_USER_HOME}"
if [[ "${CREATE_USER_LINGER}" == "true" ]]; then
    exe loginctl enable-linger "${CREATE_USER}"
fi
