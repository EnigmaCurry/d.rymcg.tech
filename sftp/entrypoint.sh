#!/bin/bash

set -ex
#sleep 2000
/usr/sbin/sshd -D -e -f /home/sshd-user/ssh/sshd_config
