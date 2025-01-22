#!/bin/bash
set -e

TARGET_USER=step

chown -R step:step /home/step/certs

# Drop privileges safely
if [ "$(id -u)" -eq 0 ]; then
    echo "Switching to user: $TARGET_USER"
    exec gosu $TARGET_USER /usr/local/bin/entrypoint-user.sh
else
    echo "This container should be run as root and it will drop privileges automatically."
    exit 1
fi
