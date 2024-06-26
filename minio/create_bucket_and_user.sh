#!/bin/bash

## Import common functions:
BIN=$(dirname ${BASH_SOURCE[0]})/../_scripts
source ${BIN}/funcs.sh

## Prompt for configuration input:
echo ""
echo "This will create a new bucket, policy, group, and user."

check_var MINIO_TRAEFIK_PORT
vars=(BUCKET POLICYNAME GROUPNAME USERNAME SECRETKEY MINIO_TRAEFIK_PORT)
require_input "Enter a new bucket name" BUCKET test
require_input "Enter a new policy name" POLICYNAME ${BUCKET}
require_input "Enter a new group name" GROUPNAME ${BUCKET}
require_input "Enter a new user name" USERNAME ${GROUPNAME}
SECRETKEY=$(openssl rand -base64 45)

## Run the mc container and pipe in the script to do everything:
DOCKER_ARGS="--env-file ${ENV_FILE:-.env} --rm -i --entrypoint=/bin/bash localhost/mc"
make --no-print-directory build service=mc
cat <<'EOF' | docker_run_with_env vars ${DOCKER_ARGS}
set -x
echo USERNAME=${USERNAME}
## Write temporary policy file:
TEMP_POLICY=$(mktemp)
cat <<FOF > ${TEMP_POLICY}
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Effect": "Allow",
     "Action": ["s3:ListBucket"],
     "Resource": ["arn:aws:s3:::${BUCKET}"]
   },
   {
     "Effect": "Allow",
     "Action": [
       "s3:PutObject",
       "s3:PutObjectTagging",
       "s3:GetObject",
       "s3:DeleteObject"
     ],
     "Resource": ["arn:aws:s3:::${BUCKET}/*"]
   }
 ]
}
FOF

set -e
## Configure endpoint with root credentials:
mc alias set minio https://${MINIO_TRAEFIK_HOST}:${MINIO_TRAEFIK_PORT} ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}
## Generate secret key:
SECRETKEY=${SECRETKEY}
## Create user:
mc admin user add minio ${USERNAME} ${SECRETKEY}
## Create group:
mc admin group add minio ${GROUPNAME} ${USERNAME}
## Create policy:
mc admin policy create minio ${POLICYNAME} ${TEMP_POLICY}
## Assign policy to group:
mc admin policy attach minio ${POLICYNAME} --group ${GROUPNAME}
## Create bucket:
mc mb minio/${BUCKET}
###
set +x
echo ""
echo "Bucket: ${BUCKET}"
echo "Endpoint: ${MINIO_TRAEFIK_HOST}"
echo "Access Key: ${USERNAME}"
echo "Secret Key: ${SECRETKEY}"
EOF
