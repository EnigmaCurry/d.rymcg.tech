#!/bin/bash

set -ex
#sleep 2000
/usr/local/bin/create-users
echo "## Config"
cat /etc/ssh/sshd_config
/usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
