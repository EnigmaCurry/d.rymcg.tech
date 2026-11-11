#!/bin/sh
set -e

timeout=300
interval=5

if [ -z "${NATS_TRAEFIK_HOST}" ]; then
    echo "NATS_TRAEFIK_HOST is empty."
    exit 1
fi

while [ $timeout -gt 0 ]; do
    if [ -f /certs/${NATS_TRAEFIK_HOST}.crt ] && \
       [ -f /certs/${NATS_TRAEFIK_HOST}.key ] && \
       [ -f /certs/root_ca.crt ]; then
        echo "## Found full TLS certificate chain."
        break
    fi
    if [ $(( (timeout / interval) % 5 )) -eq 0 ]; then
        echo "## Waiting for TLS certificate creation before startup ..."
    fi
    sleep $interval
    timeout=$((timeout - interval))
done

if [ $timeout -le 0 ]; then
    echo "## Timeout: Not all required files exist after 5 minutes."
    exit 1
fi

exec nats-server --config /etc/nats/nats.conf
