#!/bin/bash
set -e

mkdir -p ${HOME}/certs

if [[ -z "${MOSQUITTO_TRAEFIK_HOST}" ]]; then
    echo "MOSQUITTO_TRAEFIK_HOST not set."
    exit 1
fi

if [[ -z "${MOSQUITTO_STEP_CA_URL}" ]]; then
    echo "MOSQUITTO_STEP_CA_URL not set."
    exit 1
fi

if [[ -z "${MOSQUITTO_STEP_CA_FINGERPRINT}" ]]; then
    echo "MOSQUITTO_STEP_CA_FINGERPRINT not set."
    exit 1
fi


ROOT_CA="${HOME}/certs/root_ca.crt"
CERT="${HOME}/certs/${MOSQUITTO_TRAEFIK_HOST}.crt"
KEY="${HOME}/certs/${MOSQUITTO_TRAEFIK_HOST}.key"

if [[ ! -f "${ROOT_CA}" ]]; then
    step ca root ${ROOT_CA} --ca-url "${MOSQUITTO_STEP_CA_URL}" \
         --fingerprint "${MOSQUITTO_STEP_CA_FINGERPRINT}"
fi

if [[ ! -f "${KEY}" ]]; then
    if [[ -z "${MOSQUITTO_STEP_CA_TOKEN}" ]]; then
        echo "MOSQUITTO_STEP_CA_TOKEN not set. You must ask Step-CA to generate a one-time-use token for ${MOSQUITTO_TRAEFIK_HOST}."
        exit 1
    fi
    echo "Creating certificate using one-time-use token (if this fails you may need a fresh token) ..."
    step ca certificate "${MOSQUITTO_TRAEFIK_HOST}" "${CERT}" "${KEY}" --token "${MOSQUITTO_STEP_CA_TOKEN}"
fi

if [[ ! -f "${KEY}" ]]; then
    echo "Certificate creation failed!"
    exit 1
fi

echo "Starting Step-CA renewal daemon."
step ca renew --ca-url "${MOSQUITTO_STEP_CA_URL}" --daemon "${CERT}" "${KEY}"

