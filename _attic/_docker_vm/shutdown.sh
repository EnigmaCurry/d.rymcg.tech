#!/bin/bash

set -e

VMNAME=${VMNAME:-"bookworm_vm"}
QMP_SOCKET=/tmp/${VMNAME}-qmp-sock

cat <<EOF | socat -t 30 - unix-connect:${QMP_SOCKET}
{"execute": "qmp_capabilities"}
{"execute": "system_powerdown"}
EOF
