#!/bin/sh

VMNAME=${VMNAME:-"bullseye_vm"}
MEMORY=${MEMORY:-2048}
SSH_PORT=${SSH_PORT:-10022}
VMROOT=$(realpath "VMs")
DISK_IMAGE="${VMNAME}.qcow"
DOMAIN=localdomain
MAC=${MAC:-"52:54:98:76:54:32"}
EXTRA_PORTS=${EXTRA_PORTS:-""}
HOSTFWD_HOST=${HOSTFWD_HOST:-"127.0.0.1"}
if [[ ${HOSTFWD_HOST} == "*" ]]; then HOSTFWD_HOST=""; fi

extra_ports(){
    IFS=',' read -r -a ports <<< "${EXTRA_PORTS}"
    for pair in "${ports[@]}"; do
        IFS=':' read -r -a map <<< "${pair[@]}"
        echo -n "hostfwd=tcp:${HOSTFWD_HOST}:${map[0]}-:${map[1]},"
    done
}

qemu-system-x86_64 \
	-hda "${VMROOT}/${DISK_IMAGE}" \
  -smp $(nproc) \
	-netdev user,id=net0,net=10.0.2.0/24,hostfwd=tcp:${HOSTFWD_HOST}:${SSH_PORT}-:22,$(extra_ports)hostname=${VMNAME},domainname=${DOMAIN} \
	-device e1000,netdev=net0,mac=${MAC},romfile= \
	-m ${MEMORY} \
	-boot once=n \
	-enable-kvm \
  -daemonize \
  -display none

qemu_exit_code=$?

if [[ ${qemu_exit_code} == 0 ]]; then
    echo "Booting ${VMNAME} ..."
fi

echo ""
echo "To connect to the VM, run: ssh ${VMNAME}"
