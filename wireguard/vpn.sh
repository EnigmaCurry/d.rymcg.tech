#!/bin/bash
set -e

## Setup a native wireguard client without using wg-quick nor Docker...
## NOTE: this config is for forwarding ALL non-local traffic through wireguard.
## First: install wireguard server according to:
##   https://github.com/EnigmaCurry/d.rymcg.tech/tree/master/wireguard
## Then run: `make show-wireguard-peers` to get the client config details.

## Setup:
## Copy all the details from the generated config into these variables:
WG_INTERFACE=wg0
WG_ADDRESS=10.13.17.2
WG_PRIVATE_KEY=xxxxxxxxxxxxxxxxxxxxxxxxx
WG_LISTEN_PORT=51820
WG_DNS=10.13.17.1
WG_PEER_PUBLIC_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
WG_PEER_PRESHARED_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
WG_PEER_ENDPOINT=wireguard.example.com:51820
WG_PEER_ALLOWED_IPS=0.0.0.0/0
WG_PEER_ROUTE=10.13.17.1
# ..End setup

## Reruns this script as root if it wasn't already:
[[ $UID != 0 ]] && exec sudo -E "$(readlink -f "$0")" "$@"

## helper functions:
stderr(){ echo "$@" >/dev/stderr; }
error(){ stderr "Error: $@"; }
fault(){ test -n "$1" && error $1; stderr "Exiting."; exit 1; }
check_deps() {
    local __missing=false
    local __deps="$@"
    for __dep in ${__deps}; do
        which ${__dep} > /dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            error "Missing dependency: $__dep"
            __missing=true
        fi
    done
    if [[ ${__missing} == true ]]; then
        fault
    fi
}

## script actions:
up() {
    check_deps wg ip
    set -x
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
    wg set ${WG_INTERFACE} \
       listen-port ${WG_LISTEN_PORT} \
       private-key ${TMP_PRIVATE_KEYFILE}

    ## Set the peer public key, preshared key file, endpoint,
    ## and allowed IP range for the VPN:
    wg set ${WG_INTERFACE} \
       peer ${WG_PEER_PUBLIC_KEY} \
       preshared-key ${TMP_PEER_PRESHARED_KEYFILE} \
       endpoint ${WG_PEER_ENDPOINT} \
       allowed-ips ${WG_PEER_ALLOWED_IPS}

    ## Bring up the interface:
    ip link set ${WG_INTERFACE} up

    ## Remove the temporary files:
    rm -f ${TMP_PRIVATE_KEYFILE} ${TMP_PEER_PRESHARED_KEYFILE}

    ## Set rule-based routing (https://www.wireguard.com/netns/#the-classic-solutions)
    wg set ${WG_INTERFACE} fwmark 1234
    ip route add default dev ${WG_INTERFACE} table 2468
    ip rule add not fwmark 1234 table 2468
    ip rule add table main suppress_prefixlength 0
    
    ## Add all the routes from the comma separated list of WG_PEER_ALLOWED_IPS:
    # for i in ${WG_PEER_ALLOWED_IPS//,/ }
    # do
    #     ip route add ${i} via ${WG_PEER_ROUTE} dev ${WG_INTERFACE}
    # done
   
    ## Show the interface config:
    ip addr show dev ${WG_INTERFACE}
    
    ## Show the current wireguard status:
    wg    
}

down() {
    check_deps ip
    set -x
    ip link del dev ${WG_INTERFACE}
}

usage() {
    echo "Usage: $0 up|down" >&2
    exit 1
}

if [[ $# == 0 ]]; then
    usage
fi
command="$1"
shift

case "$command" in
    up) up "$@" ;;
    down) down "$@" ;;
    *) usage;;
esac
