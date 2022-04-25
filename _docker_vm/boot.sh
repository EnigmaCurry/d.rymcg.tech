#!/bin/sh

set -e

VMNAME=${VMNAME:-"bullseye_vm"}
MEMORY=${MEMORY:-2048}
SSH_PORT=${SSH_PORT:-10022}
VMROOT=$(realpath "VMs")
DISK_IMAGE="${VMNAME}.qcow"
DOMAIN=localdomain
MAC=${MAC:-"52:54:98:76:54:32"}
EXTRA_PORTS=${EXTRA_PORTS:-""}
HOSTFWD_HOST=${HOSTFWD_HOST:-"127.0.0.1"}
QMP_SOCKET=/tmp/${VMNAME}-qmp-sock
if [[ ${HOSTFWD_HOST} == "*" ]]; then HOSTFWD_HOST=""; fi

extra_ports(){
    IFS=',' read -r -a ports <<< "${EXTRA_PORTS}"
    for pair in "${ports[@]}"; do
        IFS=':' read -r -a map <<< "${pair[@]}"
        echo -n "hostfwd=tcp:${HOSTFWD_HOST}:${map[0]}-:${map[1]},"
    done
}

EXTRA_PORTS=$(extra_ports)

echo ""
echo ""
echo "Booting Docker VM now ... "

(set -x
qemu-system-x86_64 \
  -hda "${VMROOT}/${DISK_IMAGE}" \
  -smp $(nproc) \
  -netdev user,id=net0,net=10.0.2.0/24,hostfwd=tcp:${HOSTFWD_HOST}:${SSH_PORT}-:22,${EXTRA_PORTS}hostname=${VMNAME},domainname=${DOMAIN} \
  -device e1000,netdev=net0,mac=${MAC},romfile= \
  -m ${MEMORY} \
  -boot once=n \
  -enable-kvm \
  -qmp unix:${QMP_SOCKET},server,nowait \
  -display none \
  -serial stdio
)
QEMU_EXIT=$?

if [[ $QEMU_EXIT == 0 ]]; then
    echo "Qemu shutdown gracefully."
else
    echo "Qemu shutdown aburptly with code ${QEMU_EXIT}!"
    exit 1
fi
