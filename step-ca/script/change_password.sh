#!/bin/bash

set -exo pipefail

## This script is to be copied into the step-ca container and run inside it.
## https://smallstep.com/docs/step-ca/provisioners/#changing-a-jwk-provisioner-password

OLD_ENCRYPTED_KEY=$(step ca provisioner list \
                        | jq -r '.[] | select(.name == "admin").encryptedKey')

ENCRYPTED_KEY=$(echo $OLD_ENCRYPTED_KEY | \
                    step crypto jwe decrypt | \
                    step crypto jwe encrypt --alg PBES2-HS256+A128KW | \
                    step crypto jose format)

step ca provisioner update admin \
     --private-key=<(echo -n "$ENCRYPTED_KEY")

killall -1 step-ca
