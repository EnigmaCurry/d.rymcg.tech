#!/bin/sh

echo ${MOTD} > /root/.ssh/motd
touch /root/.ssh/authorized_keys && \
touch /root/.ssh/whitelist_keys && \
test -f /root/.ssh/id_rsa || ssh-keygen -C "chatkey" -f /root/.ssh/id_rsa -q -N ""
