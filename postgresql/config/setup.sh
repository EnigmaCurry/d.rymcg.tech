#!/bin/bash

set -e

CONFIG_DIR=/config
# The name of the CA:
ROOT_CA_NAME="${ROOT_CA_NAME:-Example CA}"
# 100 year certificate expiration by default:
CERTIFICATE_EXPIRATION="${CERTIFICATE_EXPIRATION:-876000h}"
# Allowed IP address source range:
POSTGRES_ALLOWED_IP_SOURCERANGE="${POSTGRES_ALLOWED_IP_SOURCERANGE:-0.0.0.0/0}"
## The certificates are only created one time, on the first startup.. Unless
## FORCE_NEW_CERTIFICATES=true, which will then overrwrite the existing
## certificates with a brand new PKI (CA+server+client certs).
FORCE_NEW_CERTIFICATES="${FORCE_NEW_CERTIFICATES:-false}"
## You can use the default EC key type or change to the RSA key type.
## EC Keys use PK12 key type (`-----BEGIN EC PRIVATE KEY-----`)
## RSA Keys use PKCS8 key type (`-----BEGIN PRIVATE KEY-----`)
#KEY_ARGS="--kty RSA --size 2048"
KEY_ARGS=""

create_config() {
    cd ${CONFIG_DIR}
    mkdir -p ${CONFIG_DIR}
    cat /template/postgresql.conf | envsubst > postgresql.conf
    echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${CONFIG_DIR}/postgresql.conf"
    cat /template/pg_hba.conf | envsubst > pg_hba.conf
    echo "[ ! ] GENERATED NEW CONFIG FILE ::: ${CONFIG_DIR}/pg_hba.conf"
}

configure_postgres_archive() {
    cat <<'EOF' >> postgresql.conf

archive_command = 'pgbackrest --stanza=apps archive-push %p'
archive_mode = on
max_wal_senders = 3
wal_level = replica

EOF
}

create_pgbackrest_config() {
    if [[ "${POSTGRES_PGBACKREST}" == "true" ]]; then
        configure_postgres_archive
        cat <<EOF > pgbackrest.conf
[apps]
pg1-path=/var/lib/postgresql/data

[global:archive-push]
compress-level=3

[global]
start-fast=y
EOF
        if [[ "${POSTGRES_PGBACKREST_LOCAL}" == "true" ]]; then
            configure_pgbackrest_local
        fi
        if [[ "${POSTGRES_PGBACKREST_S3}" == "true" ]]; then
            configure_pgbackrest_s3
        fi
    fi
}

configure_pgbackrest_local() {
    ## ASSUMES that [global] section is already at the bottom!
    cat <<EOF >> pgbackrest.conf
repo1-block=y
repo1-bundle=y
repo1-path=/var/lib/pgbackrest
repo1-retention-full=${POSTGRES_PGBACKREST_LOCAL_RETENTION_FULL:-2}
repo1-retention-diff=${POSTGRES_PGBACKREST_LOCAL_RETENTION_DIFF:-2}
EOF
        if [[ -n "${POSTGRES_PGBACKREST_ENCRYPTION_PASSPHRASE}" ]]; then
            cat <<EOF >> pgbackrest.conf
repo1-cipher-pass=${POSTGRES_PGBACKREST_ENCRYPTION_PASSPHRASE}
repo1-cipher-type=aes-256-cbc
EOF
        fi
}

configure_pgbackrest_s3() {
    ## ASSUMES that [global] section is already at the bottom!
    cat <<EOF >> pgbackrest.conf
repo2-type=s3
repo2-block=y
repo2-bundle=y
repo2-path=/apps-repo
repo2-s3-bucket=${POSTGRES_PGBACKREST_S3_BUCKET}
repo2-s3-endpoint=${POSTGRES_PGBACKREST_S3_ENDPOINT}
repo2-s3-key=${POSTGRES_PGBACKREST_S3_KEY_ID}
repo2-s3-key-secret=${POSTGRES_PGBACKREST_S3_KEY_SECRET}
repo2-s3-region=${POSTGRES_PGBACKREST_S3_REGION}
repo2-retention-full=${POSTGRES_PGBACKREST_S3_RETENTION_FULL:-2}
repo2-retention-diff=${POSTGRES_PGBACKREST_S3_RETENTION_DIFF:-2}
EOF
        if [[ -n "${POSTGRES_PGBACKREST_ENCRYPTION_PASSPHRASE}" ]]; then
            cat <<EOF >> pgbackrest.conf
repo2-cipher-pass=${POSTGRES_PGBACKREST_ENCRYPTION_PASSPHRASE}
repo2-cipher-type=aes-256-cbc
EOF
        fi
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
    step certificate create --insecure --no-password --profile root-ca ${KEY_ARGS} "${ROOT_CA_NAME}" root_ca.crt root_ca.key

    ## Create the server certificate:
    step certificate create --insecure --no-password --profile leaf ${KEY_ARGS} "${POSTGRES_HOST}" server.crt server.key --not-after="${CERTIFICATE_EXPIRATION}" --ca root_ca.crt --ca-key root_ca.key

    ## Create the client certificate:
    step certificate create --insecure --no-password --profile leaf ${KEY_ARGS} "${POSTGRES_LIMITED_USER}" client.crt client.key --not-after="${CERTIFICATE_EXPIRATION}" --ca root_ca.crt --ca-key root_ca.key

    ## Make a copy of the client key in PK8 format - rust-native-tls needs this.
    openssl pkcs8 -topk8 -nocrypt -in client.key -out client.pk8.key

    ## Fix permissions for the postgres group to access:
    chmod 0040 {root_ca,server,client}.{key,crt} client.pk8.key
    chown 0:999 {root_ca,server,client}.{key,crt} client.pk8.key
    chown 0:0 .

    ## Remove the root CA key, so that no more certificates can be issued:
    shred -u root_ca.key
}


create_config
create_pgbackrest_config
create_certs
