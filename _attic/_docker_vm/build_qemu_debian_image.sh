#!/bin/bash -e

### Forked from opencollab - https://github.com/opencollab/qemu-debian-install-pxe-preseed
### and from sigmaris - https://gist.github.com/sigmaris/dc1883f782d1ff5d74252bebf852ec50
### No license was found for these works, but thank-you very much!

set -e

## Export all vars to be used in the template preseed.cfg:
export DISTRO=${DISTRO:-bookworm}
export DISK=${DISK:-10G}
export VMNAME=${VMNAME:-"${DISTRO}_vm"}
export DOMAIN=${DOMAIN:-localdomain}
export LOCALE=${LOCALE:-en_US}
export DEBIAN_MIRROR=${DEBIAN_MIRROR:-mirrors.vcea.wsu.edu}
export TIMEZONE=${TIMEZONE:-Etc/UTC}
export AUTHORIZED_KEYS=${AUTHORIZED_KEYS:-$(ssh-add -L | head -1)}
export VMROOT=$(realpath "VMs")
export NETBOOT_IMAGE=${NETBOOT_IMAGE:-https://${DEBIAN_MIRROR}/debian/dists/${DISTRO}/main/installer-amd64/current/images/netboot/netboot.tar.gz}

## To use a development netboot installer (currently required for Debian bookworm):
#export NETBOOT_IMAGE=https://d-i.debian.org/daily-images/amd64/daily/netboot/netboot.tar.gz


mkdir -p netboot
NETBOOT_TARBALL=$(realpath netboot/netboot-${DISTRO}.tar.gz)
MAC=${MAC:-"52:54:98:76:54:32"}
DISK_IMAGE="${VMROOT}/${VMNAME}.qcow"

test -f ${DISK_IMAGE} && echo "Existing disk image found for ${VMNAME}. Skipping installation." && exit 0

test -z "${AUTHORIZED_KEYS}" && echo "You must first run 'ssh-keygen' to create your user's SSH key, and then add your key to the ssh-agent." && exit 1


check_dep(){
    if ! which $1 >/dev/null; then
        echo "Missing dependency: $1" && exit 1
    fi
}
check_dep qemu-system-x86_64
check_dep qemu-img
check_dep uv
check_dep nc
check_dep curl
check_dep openssl

TEMP="$(realpath $(mktemp -d build.XXXXX))"
## Render preseed template using environment variables:
cat preseed.cfg | envsubst > $TEMP/preseed.cfg
pushd $TEMP

ROOT_PASSWORD="$(openssl rand -base64 18)"
echo "vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv"
echo "==> Randomised root password is: $ROOT_PASSWORD <=="
echo ${ROOT_PASSWORD} > ${VMROOT}/${VMNAME}-root-pass.txt
echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
CRYPTED_PASSWORD="$(openssl passwd -1 -salt xyz ${ROOT_PASSWORD})"

echo "Running simple webserver on port 4321 for host files..."
PYTHON_PID=$(sh -c 'echo $$ ; exec >/dev/null 2>&1 ; exec uv run python3 -m http.server 4321' &)

echo "Running netcat to capture syslogs..."
NC_PID=$(sh -c 'echo $$ ; exec > ${VMROOT}/${VMNAME}-installer.log 2>&1 ; exec nc -ul 10514' &)

## Clean up regardless if the script is successful or is killed:
trap 'echo "Cleaning up processes..."; kill ${PYTHON_PID} ${NC_PID}; echo "Removing temporary directory ${TEMP} ..."; rm -rf ${TEMP}' EXIT

echo "Downloading Debian ${DISTRO} x86_64 netboot installer..."
rm -f ${NETBOOT_TARBALL}
curl --location --output ${NETBOOT_TARBALL} ${NETBOOT_IMAGE} || rm ${NETBOOT_TARBALL}
mkdir -p tftpserver
pushd tftpserver
tar xzvf ${NETBOOT_TARBALL}

echo "Customising network boot parameters..."
cat > debian-installer/amd64/pxelinux.cfg/default <<EOF
serial 0
prompt 0
default autoinst
label autoinst
kernel debian-installer/amd64/linux
append initrd=debian-installer/amd64/initrd.gz auto=true priority=critical passwd/root-password-crypted=${CRYPTED_PASSWORD} DEBIAN_FRONTEND=text url=http://10.0.2.2:4321/preseed.cfg log_host=10.0.2.2 log_port=10514 --- console=ttyS0
EOF
popd

echo "Creating disk image for Debian ${DISTRO} x86_64..."
qemu-img create -f qcow2 "${DISK_IMAGE}" ${DISK}

echo "Running Debian Installer..."
qemu-system-x86_64 \
  -cpu host \
  -hda "${DISK_IMAGE}" \
  -netdev user,id=net0,net=10.0.2.0/24,hostname=${VMNAME},domainname=${DOMAIN},tftp=tftpserver,bootfile=/pxelinux.0 \
  -device e1000,netdev=net0,mac=${MAC} \
  -boot once=n \
  -m 2048 \
  -nographic \
  -enable-kvm

popd
