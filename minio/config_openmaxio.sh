#!/bin/bash

## Import common functions:
BIN=$(dirname ${BASH_SOURCE[0]})/../_scripts
source ${BIN}/funcs.sh

## Prompt for configuration input:
echo ""
echo "This will configure OpenMaxIO to connect to MinIO."

check_var MINIO_TRAEFIK_PORT MINIO_OPENMAXIO_ACCESS_KEY MINIO_OPENMAXIO_SECRET_KEY
vars=(MINIO_TRAEFIK_PORT MINIO_OPENMAXIO_ACCESS_KEY MINIO_OPENMAXIO_SECRET_KEY)

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
## Configure OpenMaxIO Console endpoint:
mc alias set openmaxio https://${MINIO_TRAEFIK_HOST} ${MINIO_OPENMAXIO_ACCESS_KEY} ${MINIO_OPENMAXIO_SECRET_KEY}
## Create user:
mc admin user add openmaxio ${MINIO_OPENMAXIO_ACCESS_KEY} ${MINIO_OPENMAXIO_SECRET_KEY}
## Create group:
mc admin group add openmaxio openmaxio-console openmaxio-console
## Create policy:
mc admin policy create openmaxio openmaxio-console ${TEMP_POLICY}
## Assign policy to group:
mc admin policy attach openmaxio openmaxio-console --group openmaxio-console
###
set +x
echo ""
echo "Endpoint: https://${MINIO_TRAEFIK_HOST}"
echo "Access Key: ${MINIO_OPENMAXIO_ACCESS_KEY}"
echo "Secret Key: ${MINIO_OPENMAXIO_SECRET_KEY}"
echo
EOF
