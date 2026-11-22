#!/bin/bash

## Import common functions:
BIN=$(dirname ${BASH_SOURCE[0]})/../_scripts
source ${BIN}/funcs.sh

## Prompt for configuration input:
echo
echo "This will configure the console to connect to MinIO."
echo

check_var MINIO_TRAEFIK_PORT MINIO_TRAEFIK_HOST MINIO_CONSOLE_TRAEFIK_HOST MINIO_CONSOLE_ACCESS_KEY MINIO_CONSOLE_SECRET_KEY MINIO_ROOT_USER MINIO_ROOT_PASSWORD
vars=(MINIO_TRAEFIK_PORT MINIO_TRAEFIK_HOST MINIO_CONSOLE_TRAEFIK_HOST USERNAME USERPASSWORD GROUPNAME POLICYNAME MINIO_ROOT_USER MINIO_ROOT_PASSWORD)
USERNAME=${MINIO_CONSOLE_ACCESS_KEY}
USERPASSWORD=${MINIO_CONSOLE_SECRET_KEY}
GROUPNAME=${MINIO_CONSOLE_ACCESS_KEY}
POLICYNAME=${MINIO_CONSOLE_ACCESS_KEY}

## Run the mc container and pipe in the script to do everything:
DOCKER_ARGS="--env-file ${ENV_FILE:-.env} --rm -i --entrypoint=/bin/bash localhost/mc"
make --no-print-directory build service=mc
cat <<'EOF' | docker_run_with_env vars ${DOCKER_ARGS}
set -x
## Write temporary policy file:
TEMP_POLICY=$(mktemp)
cat <<FOF > ${TEMP_POLICY}
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": ["admin:*"],
      "Effect": "Allow",
      "Sid": ""
    },
    {
      "Action": ["s3:*"],
      "Effect": "Allow",
      "Resource": ["arn:aws:s3:::*"],
      "Sid": ""
    }
  ]
}
FOF
set -e
## Create console endpoint:
mc alias set minio https://${MINIO_TRAEFIK_HOST}:${MINIO_TRAEFIK_PORT} ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}
## Create user:
mc admin user add minio ${USERNAME} ${USERPASSWORD}
## Create group:
mc admin group add minio ${GROUPNAME} ${USERNAME}
## Create policy:
mc admin policy create minio ${POLICYNAME} ${TEMP_POLICY}
## Assign policy to group:
mc admin policy attach minio ${POLICYNAME} --group ${GROUPNAME}
###
set +x
echo
echo "Console access key \"${USERNAME}\" created."
echo
EOF
