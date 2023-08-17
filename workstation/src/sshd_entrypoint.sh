#!/bin/bash

set -e

if [[ "$(id -u)" != "0" ]]; then echo "This script must be run as root"; exit 1; fi;

## Create the workstation user and groups and add sudo privileges:
WORKSTATION_UID=${WORKSTATION_UID:-1000}
WORKSTATION_GID=${WORKSTATION_GID:-1000}
WORKSTATION_USER=${WORKSTATION_USER:-user}
WORKSTATION_HOME=/home/${WORKSTATION_USER}
WORKSTATION_SSH_PORT=${WORKSTATION_SSH_PORT:-2222}
groupadd -g ${WORKSTATION_GID} ${WORKSTATION_USER}
useradd -d ${WORKSTATION_HOME} -m --uid=${WORKSTATION_UID} --gid=${WORKSTATION_GID} --shell=/bin/bash ${WORKSTATION_USER}
gpasswd -a ${WORKSTATION_USER} sudo
mkdir -p ${WORKSTATION_HOME}/ssh/keys
cp /usr/local/template/d.rymcg.tech-workstation/bash_profile.sh ${WORKSTATION_HOME}/.bash_profile
chown -R ${WORKSTATION_USER}:${WORKSTATION_USER} ${WORKSTATION_HOME} /run/sshd
echo "+:${WORKSTATION_USER}:ALL" >> /etc/security/access.conf
if ! grep 'd.rymcg.tech' ${WORKSTATION_HOME}/.bashrc; then
    cat /usr/local/template/d.rymcg.tech-workstation/bashrc.sh >> ${WORKSTATION_HOME}/.bashrc
fi

## Create the sshd_config:
mkdir -p /etc/ssh
cat <<EOF > /etc/ssh/sshd_config
Port ${WORKSTATION_SSH_PORT}
Protocol 2
HostKey ${WORKSTATION_HOME}/ssh/keys/ssh_host_ed25519_key
HostKey ${WORKSTATION_HOME}/ssh/keys/ssh_host_rsa_key
PidFile ${WORKSTATION_HOME}/ssh/sshd.pid

## Don't use pam because it requires root:
UsePam no

## Dont use dns names in authorized_keys file (require ip address instead)
UseDNS no

# Limited access
PermitRootLogin no
AllowUsers ${WORKSTATION_USER}
DisableForwarding yes
AuthenticationMethods publickey

# LogLevel DEBUG
EOF
chmod 0444 /etc/ssh/sshd_config

## Create docker group if docker socket found:
DOCKER_SOCKET=/var/run/docker.sock
if [[ -e "${DOCKER_SOCKET}" ]]; then
    DOCKER_SOCKET_GID="$(stat -c '%g' "${DOCKER_SOCKET}")"
    groupadd -g ${DOCKER_SOCKET_GID} docker
    gpasswd -a ${WORKSTATION_USER} docker
fi

echo "----------------------------------------"
echo "## Startup at $(date)"
mkdir -p ${WORKSTATION_HOME}/ssh/keys
for key_type in ed25519 rsa; do
    if [[ ! -f ${WORKSTATION_HOME}/ssh/keys/ssh_host_${key_type}_key ]]; then
        echo "Generating new SSH host key type: ${key_type}"
        HOST_KEY="${WORKSTATION_HOME}/ssh/keys/ssh_host_${key_type}_key"
        ssh-keygen -N "" -t "${key_type}" -f "${HOST_KEY}"
        chown "${WORKSTATION_USER}:${WORKSTATION_USER}" "${HOST_KEY}"
    fi
done

# Run sshd as the workstation user:
/usr/bin/setpriv --reuid="${WORKSTATION_UID}" --regid="${WORKSTATION_GID}" --init-groups /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
