#!/bin/bash

## Teardown existing wireguard connection
WG_INTERFACE=wg0

if [ `id -u` -ne 0 ]
  then echo Please run this script as root or using sudo!
  exit
fi

set -ex

ip link del dev ${WG_INTERFACE}
