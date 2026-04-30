#!/bin/bash

# Example to run public webserver, postgresql, and SSH on unprivileged ports:
export VMNAME="docker-vm"
export EXTRA_PORTS='8000:80,8443:443,5432:5432,2222:2222'
export HOSTFWD_HOST='*'

make install
make enable
