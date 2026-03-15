#!/bin/sh
## Creates the SSH signing role for short-lived certificates.
## This script runs inside the openbao container.
## Usage: bao write ... uses stdin for default_extensions JSON.
set -e

bao write ssh-client-signer/roles/woodpecker-short-lived \
    allow_user_certificates=true \
    allowed_users="*" \
    key_type=ca \
    default_user=root \
    ttl=2m \
    max_ttl=5m \
    algorithm_signer=default \
    default_extensions='{"permit-pty":"","permit-port-forwarding":""}'
