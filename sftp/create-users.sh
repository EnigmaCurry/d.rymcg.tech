#!/bin/bash

set -e

IFS=',' read -ra users <<< "$SFTP_USERS"
for user_entry in "${users[@]}"; do
    parts=(${user_entry//:/ }); user=${parts[0]}; uid=${parts[@]:1};
    addgroup --gid "${uid}" "${user}"
    adduser --no-create-home --home "/${user}" --disabled-password "${user}" --gecos GECOS --uid "${uid}" --gid "${uid}"
    mkdir -p "/data/${user}-chroot/${user}" && chmod o-rwx "/data/${user}-chroot/${user}" && chown "${user}:${user}" "/data/${user}-chroot/${user}"
    echo "Created user: ${user}"
done
