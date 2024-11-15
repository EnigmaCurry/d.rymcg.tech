#!/bin/sh
set -e

UID=${UID:-1000}
GID=${GID:-1000}

if [ -z "$@" ]; then
    echo "Error: no command was specififed." >/dev/stderr
    exit 1
fi

# Check if the group exists, if not, create it
if ! getent group ${GID} >/dev/null; then
    echo "Creating group with GID ${GID}"
    groupadd -g ${GID} appgroup
fi

# Check if the user exists, if not, create it
if ! getent passwd ${UID} >/dev/null; then
    echo "Creating user with UID ${UID}"
    useradd -u ${UID} -g ${GID} -d /app -s /bin/sh appuser
fi

# Change ownership of /app to the UID and GID
echo "Changing ownership of /app to UID ${UID} and GID ${GID}"
chown -R ${UID}:${GID} /app

# Execute php-fpm or whatever command was passed
exec "$@"
