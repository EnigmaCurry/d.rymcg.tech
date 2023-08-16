#!/bin/bash

echo "----------------------------------------"
echo "## Startup at $(date)"
mkdir -p /home/ssh/keys
for key_type in ed25519 rsa; do
    if [[ ! -f /home/ssh/keys/ssh_host_${key_type}_key ]]; then
        echo "Generating new SSH host key type: ${key_type}"
        ssh-keygen -N "" -t "${key_type}" -f "/home/ssh/keys/ssh_host_${key_type}_key"
    fi
done

/usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
