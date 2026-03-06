#!/bin/bash

CONFIG_DIR=/etc/nats
CONFIG=${CONFIG_DIR}/nats.conf

if [[ -z "${NATS_CLUSTER_NAME}" ]]; then
    echo "NATS_CLUSTER_NAME is empty."
    exit 1
fi

if [[ -z "${NATS_TRAEFIK_HOST}" ]]; then
    echo "NATS_TRAEFIK_HOST is empty."
    exit 1
fi

echo "Creating new NATS config from template ..."
mkdir -p ${CONFIG_DIR}
cat /template/nats.conf | envsubst '${NATS_CLUSTER_NAME},${NATS_TRAEFIK_HOST}' > ${CONFIG}
echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${CONFIG}"
