#!/bin/bash
set -e
BIN=../_scripts
source ${BIN}/funcs.sh

VM_ADMIN="${VM_ADMIN:-libvirt-admin}"
VM_USER="${VM_USER:-root}"
VM_ADMIN_HOME="$(getent passwd ${VM_ADMIN} | cut -d: -f6)"
SSH_KEY="${SSH_KEY:-$(cat ${HOME}/.ssh/id_ed25519.pub | head -1)}"

NAME="${NAME:-debian-dev}"
MEMORY="${MEMORY:-1024}"
CPUS="${CPUS:-1}"
DISK_SIZE="${DISK_SIZE:-50}"
OS_VARIANT="${OS_VARIANT:-debian12}"
CLOUD_IMAGE="${CLOUD_IMAGE:-https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2}"
IP_ADDRESS="${IP_ADDRESS:-192.168.122.2}"
MAC_ADDRESS="${MAC_ADDRESS:-$(printf '00:60:2F:%02X:%02X:%02X\n' $[RANDOM%256] $[RANDOM%256] | tr '[:upper:]' '[:lower:]')}"

USER_DATA="${VM_ADMIN_HOME}/libvirt/cloud-init/${NAME}.yaml"

check_var NAME MEMORY CPUS DISK_SIZE OS_VARIANT CLOUD_IMAGE IP_ADDRESS \
          MAC_ADDRESS USER_DATA

usage() {
    echo "Usage: $0 TODO" >&2
    exit 1
}

vm_save_config() {
    TMP_ENV=$(mktemp)
    cat << EOF > ${TMP_ENV}
export NAME=${NAME}
export OS_VARIANT=${OS_VARIANT}
export IP_ADDRESS=${IP_ADDRESS}
export MAC_ADDRESS=${MAC_ADDRESS}
export CLOUD_IMAGE=${CLOUD_IMAGE}
export MEMORY=${MEMORY}
export CPUS=${CPUS}
export DISK_SIZE=${DISK_SIZE}
export USER_DATA=${USER_DATA}
EOF
    chmod a+r ${TMP_ENV}
    sudo su ${VM_ADMIN:-libvirt-admin} -c \
         "mkdir -p ~/libvirt && cp ${TMP_ENV} ~/libvirt/${NAME}.env"
}

vm_dhcp_lease() {
    sudo virsh net-update default add-last ip-dhcp-host \
         "<host mac='${MAC_ADDRESS}' name='${NAME}' ip='${IP_ADDRESS}' />" \
         --live --config --parent-index 0
}

libvirt_dhcp_flush() {
    sudo virsh net-edit default
    sudo virsh net-destroy default
    sudo rm /var/lib/libvirt/dnsmasq/virbr0.status
    sudo virsh net-start default
    sudo virsh net-dhcp-leases default
}

libvirt_enable() {
    sudo systemctl enable --now libvirtd
    sudo systemctl enable --now libvirt-guests
    sudo virsh net-start default || true
    sudo virsh net-autostart default
    sudo systemctl status --no-pager libvirtd
}

libvirt_create_admin_user() {
    if ! id -u ${VM_ADMIN} >/dev/null; then
        sudo useradd -m ${VM_ADMIN} -s /bin/bash -G libvirt
        sudo loginctl enable-linger ${VM_ADMIN}
        sudo su ${VM_ADMIN} -c \
             "echo export XDG_RUNTIME_DIR=/run/user/$(id -u ${VM_ADMIN}) > ~/.bashrc"
        sudo su ${VM_ADMIN} -c \
             "mkdir -p ${VM_ADMIN_HOME}/libvirt/{cloud-images,disks,cloud-init}"
    fi
}

libvirt_install_packages() {
    if [[ -f /etc/redhat-release ]]; then
        cat /etc/redhat-release
        if ${BIN}/check_deps dnf; then
            # Traditional fedora like
            (set -x
             sudo dnf install qemu-kvm libvirt virt-manager virt-viewer \
                 virt-install libvirt-daemon-config-network libvirt-daemon-kvm \
                 libguestfs-tools python3-libguestfs virt-top net-tools
            )
            
        elif ${BIN}/check_deps rpm-ostree; then
            # Fedora Atomic / CoreOS
            (set -x
            sudo rpm-ostree install qemu-kvm libvirt virt-manager virt-viewer \
                 virt-install libvirt-daemon-config-network libvirt-daemon-kvm \
                 libguestfs-tools python3-libguestfs virt-top distrobox make
            )
        else
            fault "Detected a redhat type release, but no package manager?"
        fi
    elif [[ -f /etc/os-release ]]; then
        DISTRO=$(cat /etc/os-release | grep -Po '^NAME=\K.*' | tr -d '"')
        if [[ "${DISTRO}" == "Arch Linux" ]]; then
            (set -x
            sudo pacman -S libvirt iptables-nft dnsmasq qemu-base virt-install \
               sysfsutils bridge-utils ebtables git make which jq \
               dmidecode pkgconf gcc
            )
        elif [[ "${DISTRO}" == "Debian" ]] || [[ "${DISTRO}" == "Ubuntu" ]]; then
            (set -x
            sudo apt install --no-install-recommends \
                 libvirt-daemon-system virtinst libvirt-clients \
                 dnsmasq sysfsutils bridge-utils ebtables git make \
                 which jq dmidecode pkgconf gcc curl \
                 python3 python-is-python3
            )
        fi
        fault Sorry, ${DISTRO} is not supported yet.
    else
        fault Sorry, your Linux distribution cannot be detected.
    fi
    # Ensure the libvirt group is configured:
    grep "^libvirt:" /etc/group \
        || sudo bash -c "getent group libvirt >> /etc/group"
}

admin_exec() {
    sudo -u ${VM_ADMIN} "XDG_RUNTIME_DIR=/run/user/$(id -u ${VM_ADMIN})" bash
}

admin_config() {
    cat <<EOF | admin_exec
cat ${VM_ADMIN_HOME}/libvirt/${NAME}.env
EOF
}

admin_cloud_image() {
    cat <<EOF | admin_exec
(set -ex
cd ${VM_ADMIN_HOME}/libvirt/cloud-images
curl -LO ${CLOUD_IMAGE}
chmod a-w $(echo ${CLOUD_IMAGE} | grep -Po ".*/\K.*$")
)
EOF
}

admin_cloud_init() {
    cat <<EOF | sudo -u ${VM_ADMIN} tee ${USER_DATA}
#cloud-config
hostname: ${NAME}
users:
  - name: ${VM_USER}
    ssh_authorized_keys:
      - ${SSH_KEY}
EOF
}

admin_reset_disk() {
    cat <<EOF | admin_exec
(set -ex
cp ${VM_ADMIN_HOME}/libvirt/cloud-images/$(echo ${CLOUD_IMAGE} | grep -Po ".*/\K.*") ${VM_ADMIN_HOME}/libvirt/disks/${NAME}.qcow2
chmod u+w ${VM_ADMIN_HOME}/libvirt/disks/${NAME}.qcow2
qemu-img resize ${VM_ADMIN_HOME}/libvirt/disks/${NAME}.qcow2 +${DISK_SIZE}G
echo Created ${VM_ADMIN_HOME}/libvirt/disks/${NAME}.qcow2
)
EOF
}

admin_create_vm() {
    sudo -u ${VM_ADMIN} "XDG_RUNTIME_DIR=/run/user/$(id -u ${VM_ADMIN})" \
         virt-install \
         --name ${NAME} \
         --os-variant ${OS_VARIANT} \
         --virt-type kvm \
         --graphics none \
         --console pty,target_type=serial \
         --cpu host \
         --vcpus ${CPUS} \
         --memory ${MEMORY} \
         --network bridge=virbr0,model=virtio,mac=${MAC_ADDRESS} \
         --cloud-init user-data=${USER_DATA} \
         --import \
         --disk ${VM_ADMIN_HOME}/libvirt/disks/${NAME}.qcow2
}

admin_virsh() {
    cat <<EOF | admin_exec
set -ex
virsh $@
EOF
}

menu() {
    q
}

main() {
    if [[ $# == 0 ]]; then
        menu
    fi
    command="$1"
    shift

    case "$command" in
        enable) libvirt_enable ;;
        save_config) vm_save_config ;;
        create_user) libvirt_create_admin_user ;;
        copy_ssh_key) libvirt_copy_ssh_key ;;
        install_packages) libvirt_install_packages ;;
        dhcp_flush) libvirt_dhcp_flush ;;
        dhcp_lease) vm_dhcp_lease ;;
        config) admin_config ;;
        cloud_init) admin_cloud_init ;;
        cloud_image) admin_cloud_image ;;
        reset_disk) admin_reset_disk ;;
        destroy) admin_virsh destroy ${NAME} ;;
        undefine) admin_virsh undefine ${NAME} ;;
        create) admin_create_vm ;;
        *) fault "invalid command";;
    esac
}

main $@
