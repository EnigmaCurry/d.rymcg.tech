#!/bin/bash
## Copy the Step-CA trust settings from the Traefik .env file of the same
## Docker context (oauth2-proxy runs on that Traefik), so oauth2-proxy can
## trust an OIDC provider whose certificate comes from Step-CA.
##
## OAUTH2_PROXY_STEP_CA_ZERO_CERTS is not copied: for Traefik the Step-CA
## root is for verifying mTLS clients, so dropping the public CAs there is
## fine, but oauth2-proxy still needs them to reach a provider with a
## publicly trusted certificate. Adding the Step-CA root on top is harmless.

BIN=${ROOT_DIR}/_scripts
source ${BIN}/funcs.sh

DOCKER_CONTEXT=$(${BIN}/docker_context)
if [[ -n "${DRT_ENV_DIR:-}" ]]; then
    TRAEFIK_ENV="${DRT_ENV_DIR}/traefik/.env_${DOCKER_CONTEXT}_default"
else
    TRAEFIK_ENV="${ROOT_DIR}/traefik/.env_${DOCKER_CONTEXT}_default"
fi

if [[ ! -f "${TRAEFIK_ENV}" ]]; then
    echo "No Traefik env file found (${TRAEFIK_ENV}); leaving the Step-CA settings unchanged."
    exit 0
fi

ENABLED=$(${BIN}/dotenv -f "${TRAEFIK_ENV}" get TRAEFIK_STEP_CA_ENABLED 2>/dev/null || true)
ENDPOINT=$(${BIN}/dotenv -f "${TRAEFIK_ENV}" get TRAEFIK_STEP_CA_ENDPOINT 2>/dev/null || true)
FINGERPRINT=$(${BIN}/dotenv -f "${TRAEFIK_ENV}" get TRAEFIK_STEP_CA_FINGERPRINT 2>/dev/null || true)

if [[ "${ENABLED}" == "true" ]]; then
    if [[ -z "${ENDPOINT}" || -z "${FINGERPRINT}" ]]; then
        echo "Traefik has Step-CA enabled but no endpoint/fingerprint (${TRAEFIK_ENV}); leaving the Step-CA settings unchanged."
        exit 0
    fi
    ${BIN}/reconfigure ${ENV_FILE} \
        OAUTH2_PROXY_STEP_CA_ENABLED=true \
        OAUTH2_PROXY_STEP_CA_ENDPOINT="${ENDPOINT}" \
        OAUTH2_PROXY_STEP_CA_FINGERPRINT="${FINGERPRINT}"
    echo "Trusting Step-CA ${ENDPOINT} (copied from the Traefik config)."
else
    ${BIN}/reconfigure ${ENV_FILE} OAUTH2_PROXY_STEP_CA_ENABLED=false
    echo "Step-CA is not enabled in the Traefik config; oauth2-proxy won't trust it."
fi
