#!/bin/sh

set -e

VMNAME=${VMNAME:-"bullseye_vm"}
QMP_SOCKET=/tmp/${VMNAME}-qmp-sock

cat <<EOF | socat -t 30 - unix-connect:/tmp/docker-vm-qmp-sock
{"execute": "qmp_capabilities"}
{"execute": "system_powerdown"}
EOF
