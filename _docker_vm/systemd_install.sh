#!/bin/bash

SERVICE=${HOME}/.config/systemd/user/docker-vm.service
SCRIPT_ROOT=$(dirname $(realpath ${BASH_SOURCE}))

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
Environment=DOCKER_INSTALL=false
ExecStart=make -C ${SCRIPT_ROOT}

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
