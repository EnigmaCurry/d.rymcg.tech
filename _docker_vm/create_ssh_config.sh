#!/bin/sh

set -e

test -z "${VMNAME}" && echo "Must set VMNAME environment variable"
test -z "${SSH_PORT}" && echo "Must set SSH_PORT environment variable"

mkdir -p ~/.ssh

if ! grep -P "^Host ${VMNAME}" ~/.ssh/config; then
    cat <<EOF >> ~/.ssh/config


Host ${VMNAME}
     Hostname localhost
     User root
     Port ${SSH_PORT}
     StrictHostKeyChecking no
     UserKnownHostsFile /dev/null
EOF

else
    echo "SSH is already configured for host ${VMNAME}"
fi

