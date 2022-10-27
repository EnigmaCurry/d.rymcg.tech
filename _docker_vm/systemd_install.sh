#!/bin/bash

set -e

VMNAME=${VMNAME:-docker-vm}
SERVICE=${HOME}/.config/systemd/user/${VMNAME}.service
SCRIPT_ROOT=$(dirname $(realpath ${BASH_SOURCE}))
HOSTFWD_HOST=${HOSTFWD_HOST:-127.0.0.1}
EXTRA_PORTS=${EXTRA_PORTS:-8000:80,8443:443,5432:5432}

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
ExecStart=make -C ${SCRIPT_ROOT} HOSTFWD_HOST="${HOSTFWD_HOST}" EXTRA_PORTS="${EXTRA_PORTS}" VMNAME="${VMNAME}"
ExecStop=make -C ${SCRIPT_ROOT} down VMNAME="${VMNAME}"

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
