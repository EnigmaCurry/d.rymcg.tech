#!/bin/sh
## Creates the SSH signing role for short-lived certificates.
## This script runs inside the openbao container.
set -e

cat <<'EOF' | bao write ssh-client-signer/roles/woodpecker-short-lived -
{
  "allow_user_certificates": true,
  "allowed_users": "*",
  "default_extensions": {
    "permit-pty": "",
    "permit-port-forwarding": ""
  },
  "key_type": "ca",
  "default_user": "root",
  "ttl": "2m",
  "max_ttl": "5m",
  "algorithm_signer": "default"
}
EOF
