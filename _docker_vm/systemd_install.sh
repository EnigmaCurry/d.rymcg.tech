#!/bin/bash

set -e

SERVICE=${HOME}/.config/systemd/user/docker-vm.service
SCRIPT_ROOT=$(dirname $(realpath ${BASH_SOURCE}))
HOSTFWD_HOST=${HOSTFWD_HOST:-127.0.0.1}
EXTRA_PORTS=${EXTRA_PORTS:-8000:80,8443:443,5432:5432}
VM_NAME=${VM_NAME:-docker-vm}

if loginctl show-user ${USER} | grep "Linger=no"; then
	  echo "User account does not allow systemd Linger."
	  echo "To enable lingering for your user, run: sudo loginctl enable-linger ${USER}"
	  echo "Then try running this command again."
	  exit 1
fi
mkdir -p $(dirname ${SERVICE})
cat <<EOF > ${SERVICE}
[Unit]
Description=Docker Virtual Machine (${SCRIPT_ROOT})

[Service]
ExecStart=make -C ${SCRIPT_ROOT} HOSTFWD_HOST="${HOSTFWD_HOST}" EXTRA_PORTS="${EXTRA_PORTS}" VM_NAME="${VM_NAME}"
ExecStop=make -C ${SCRIPT_ROOT} down

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
