#!/bin/bash
BIN=$(dirname ${BASH_SOURCE})/../_scripts
source ${BIN}/funcs.sh

USERNAME=${1}

test -z "${USERNAME}" && require_input "Enter the username" USERNAME

set -e
PASSWORD=$(openssl rand -base64 24)
if [[ ${USERNAME} == "admin" ]]; then
    ${BIN}/confirm no "This will remove ALL the existing accounts and create a new admin account"
    command="mosquitto_passwd -c -b /mosquitto/config/passwd ${USERNAME} ${PASSWORD}"
else
    command="mosquitto_passwd -b /mosquitto/config/passwd ${USERNAME} ${PASSWORD}"
fi

docker run --rm -v mosquitto_mosquitto:/mosquitto eclipse-mosquitto ${command}
echo "Created new account:"
echo "Username: ${USERNAME}"
echo "Password: ${PASSWORD}"

