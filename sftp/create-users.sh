#!/bin/bash

set -e

IFS=',' read -ra users <<< "$SFTP_USERS"
for user_entry in "${users[@]}"; do
    parts=(${user_entry//:/ }); user=${parts[0]}; uid=${parts[@]:1};
    addgroup --gid "${uid}" "${user}"
    adduser --home "/data/${user}" --disabled-password "${user}" --gecos GECOS --uid "${uid}" --gid "${uid}"
    chown root:root "/data/${user}"
    echo "Created user: ${user}"
done
