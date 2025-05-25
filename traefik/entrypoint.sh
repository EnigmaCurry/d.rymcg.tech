#!/bin/sh

set -e
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

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
    set -- traefik "$@"
fi

# if our command is a valid Traefik subcommand, let's invoke it through Traefik instead
# (this allows for "docker run traefik version", etc)
if traefik "$1" --help >/dev/null 2>&1
then
    set -- traefik "$@"
else
    echo "= '$1' is not a Traefik command: assuming shell execution." 1>&2
fi

sleep 2
set -x
exec "$@"
