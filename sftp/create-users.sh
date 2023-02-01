#!/bin/bash

set -e

IFS=',' read -ra users <<< "$SFTP_USERS"
for user_entry in "${users[@]}"; do
    parts=(${user_entry//:/ }); user=${parts[0]}; uid=${parts[@]:1};
    USER_DIR="/data/${user}-chroot/${user}"
    getent group "${uid}" || (addgroup --gid "${uid}" "${user}" &&  echo "Created group: ${user}")
    getent passwd "${uid}" || (adduser --no-create-home --home "/${user}" --disabled-password "${user}" --gecos GECOS --uid "${uid}" --gid "${uid}" && echo "Created user: ${user}")
    mkdir -p "${USER_DIR}" && chmod o-rwx "${USER_DIR}" && chown "${user}:${user}" "${USER_DIR}" &&     echo "Created user home: ${USER_DIR}"
done
