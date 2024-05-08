#!/bin/bash

## Setup a native wireguard client without using Docker...
## Copy the details from your provided configuration into these variables:
WG_INTERFACE=wg0
WG_ADDRESS=10.13.17.3
WG_PRIVATE_KEY=iCJvDPl+CoeZUb2lN+s3eC5V17iC3Jp3js/VKvvXvVo=
WG_LISTEN_PORT=51820
WG_DNS=10.13.17.1
WG_PEER_PUBLIC_KEY=wkjo2YLYYoIvUpzmqCKOhTuCcj1xOgGOVerdKASBgVk=
WG_PEER_PRESHARED_KEY=CkZ8E+DG7n2otiurDK7youwvvnORz/2jlQfHnVI0d3k=
WG_PEER_ENDPOINT=104.131.11.43:51820
WG_PEER_ALLOWED_IPS=0.0.0.0/0
WG_PEER_ROUTE=10.13.17.1

# ..End config

if [ `id -u` -ne 0 ]
  then echo Please run this script as root or using sudo!
  exit
fi

set -ex

## Copy the private and preshared keys to temporary files:
TMP_PRIVATE_KEYFILE=$(mktemp)
TMP_PEER_PRESHARED_KEYFILE=$(mktemp)
echo ${WG_PRIVATE_KEY} > ${TMP_PRIVATE_KEYFILE}
echo ${WG_PEER_PRESHARED_KEY} > ${TMP_PEER_PRESHARED_KEYFILE}

## Create the wireguard network interface:
ip link add dev ${WG_INTERFACE} type wireguard

## Assign the IP address to the interface:
ip addr add ${WG_ADDRESS}/24 dev ${WG_INTERFACE}

## Set the private key file:
wg set ${WG_INTERFACE} listen-port ${WG_LISTEN_PORT} private-key ${TMP_PRIVATE_KEYFILE}

## Set the peer public key, preshared key file, endpoint, and allowed IP range for the VPN:
wg set ${WG_INTERFACE} \
   peer ${WG_PEER_PUBLIC_KEY} \
   preshared-key ${TMP_PEER_PRESHARED_KEYFILE} \
   endpoint ${WG_PEER_ENDPOINT} \
   allowed-ips ${WG_PEER_ALLOWED_IPS}

## Bring up the interface:
ip link set ${WG_INTERFACE} up

## Add all the routes from the comma separated list of WG_PEER_ALLOWED_IPS:
for i in ${WG_PEER_ALLOWED_IPS//,/ }
do
    ip route add ${i} via ${WG_PEER_ROUTE} dev ${WG_INTERFACE}
done

## Remove the temporary files:
rm -f ${TMP_PRIVATE_KEYFILE} ${TMP_PEER_PRESHARED_KEYFILE}

## Show the current wireguard status:
wg
