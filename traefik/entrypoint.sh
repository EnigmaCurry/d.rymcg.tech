#!/bin/sh
CONFIG=/data/config/traefik.yml

echo "Waiting for config to be created ... "
for try in 1 2 3 4 5; do
    test -f "${CONFIG}" && break
    sleep 2
    if [[ "${try}" -gt 3 ]]; then
        echo "Config not found: ${CONFIG}"
        exit 1
    fi
done
echo "Found config: ${CONFIG}"

traefik "$@"

