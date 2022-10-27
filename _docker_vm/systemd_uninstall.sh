#!/bin/bash

set -e

VMNAME=${VMNAME:-docker-vm}
SERVICE=${HOME}/.config/systemd/user/${VMNAME}.service
SCRIPT_ROOT=$(dirname $(realpath ${BASH_SOURCE}))

rm -f ${SERVICE}
systemctl --user daemon-reload
