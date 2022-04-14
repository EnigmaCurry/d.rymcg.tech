#!/bin/sh

set -e

test -z "${VMNAME}" && echo "VMNAME is not set, not installing docker." && exit 1

ssh ${VMNAME} '/bin/sh -c "which docker>/dev/null || (curl -fsSL https://get.docker.com | sh)"'

if which docker>/dev/null; then
    if ! docker context inspect ${VMNAME} >/dev/null; then
        docker context create ${VMNAME} --docker "host=ssh://${VMNAME}"
        echo "Created new remote docker context: ${VMNAME}"
        echo "To use the new docker context, run:"
        echo "docker context use ${VMNAME}"
    fi
else
    echo "You need to install the docker client on your local workstation."
    echo "Note: you do *not* need to start the docker daemon locally."
    exit 1
fi
