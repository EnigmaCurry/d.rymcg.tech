#!/bin/bash

set -e

CONFIG_DIR=/config
# The name of the CA:
ROOT_CA_NAME="${ROOT_CA_NAME:-Example CA}"
# 100 year certificate expiration by default:
CERTIFICATE_EXPIRATION="${CERTIFICATE_EXPIRATION:-876000h}"
# Allowed IP address source range:
ALLOWED_IP_SOURCERANGE="${ALLOWED_IP_SOURCERANGE:-0.0.0.0/0}"
## The certificates are only created one time, on the first startup.. Unless
## FORCE_NEW_CERTIFICATES=true, which will then overrwrite the existing
## certificates with a brand new PKI (CA+server+client certs).
FORCE_NEW_CERTIFICATES="${FORCE_NEW_CERTIFICATES:-false}"

create_config() {
    cd ${CONFIG_DIR}
    TEMPLATE=/template/s3-proxy.template.yml
    CONFIG=${CONFIG_DIR}/s3-proxy.yml

    mkdir -p ${CONFIG_DIR}
    cat /template/postgresql.conf | envsubst > postgresql.conf
    echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${CONFIG_DIR}/postgresql.conf"
    cat /template/pg_hba.conf | envsubst > pg_hba.conf
    echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${CONFIG_DIR}/pg_hba.conf"
}

create_certs() {
    cd ${CONFIG_DIR}

    ## Check if the certificates exist already, and if so skip this step
    if [[ -f server.key ]] && [[ ${FORCE_NEW_CERTIFICATES} != "true" ]]; then
        echo "Found existing certificates, not going to make new certificates unless FORCE_NEW_CERTIFICATES=true"
        return
    fi

    echo "Creating new PKI - CA + server + client certificates ... "

    ## Create the root Certificate Authority:
    step certificate create --insecure --no-password --profile root-ca "${ROOT_CA_NAME}" root_ca.crt root_ca.key

    ## Create the server certificate:
    step certificate create --insecure --no-password --profile leaf "${POSTGRES_TRAEFIK_HOST}" server.crt server.key --not-after="${CERTIFICATE_EXPIRATION}" --ca root_ca.crt --ca-key root_ca.key

    ## Create the client certificate:
    step certificate create --insecure --no-password --profile leaf "${POSTGRES_LIMITED_USER}" client.crt client.key --not-after="${CERTIFICATE_EXPIRATION}" --ca root_ca.crt --ca-key root_ca.key

    ## Make a copy of the client key in DER PK8 format (DBeaver needs this)
    openssl pkcs8 -topk8 -inform PEM -outform DER -nocrypt -in client.key -out client.pk8.key

    ## Fix permissions for the postgres group to access:
    chmod 0040 {root_ca,server,client}.{key,crt} client.pk8.key
    chown 0:999 {root_ca,server,client}.{key,crt} client.pk8.key
    chown 0:0 .

    ## Remove the root CA key, so that no more certificates can be issued:
    shred -u root_ca.key
}


create_config
create_certs
