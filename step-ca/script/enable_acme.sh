#!/bin/bash

set -exo pipefail

## This script is to be copied into the step-ca container and run inside it.
## https://smallstep.com/docs/step-ca/acme-basics/#configure-step-ca-for-acme

step ca provisioner add acme --type ACME --require-eab
killall -1 step-ca
