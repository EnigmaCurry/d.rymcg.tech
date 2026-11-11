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
     ControlMaster auto
     ControlPersist yes
     ControlPath /tmp/ssh-%u-%r@%h:%p
EOF

else
    echo "SSH is already configured for host ${VMNAME}"
fi

if which docker>/dev/null; then
    if ! docker context inspect ${VMNAME} >/dev/null; then
        docker context create ${VMNAME} --docker "host=ssh://${VMNAME}"
        echo "Created new remote docker context: ${VMNAME}"
        echo "To use the new docker context, run:"
        echo "docker context use ${VMNAME}"
    fi
else
    echo "You need to install the docker client on your local workstation."
    echo "Note: you do *NOT* need to start the local docker daemon service."
    exit 1
fi
