#!/bin/bash
set -e

## Setup a native wireguard client without using wg-quick nor Docker...
## NOTE: this config is for forwarding ALL non-local traffic through wireguard.
## First: install wireguard server according to:
##   https://github.com/EnigmaCurry/d.rymcg.tech/tree/master/wireguard
## Then run: `make show-wireguard-peers` to get the client config details.

## Setup:
## Copy all the details from the generated config into these variables:
# Name of the local wireguard interface to create:
WG_INTERFACE=wg0
# The private VPN IP address this client should use:
WG_ADDRESS=10.13.17.2
# The private key of this client:
WG_PRIVATE_KEY=xxxxxxxxxxxxxxxxxxxxxxxxx
# The UDP port this client listens on (not really used if its behind a firewall)
WG_LISTEN_PORT=51820
# The DNS setting to use when the VPN is active:
WG_DNS=10.13.17.1
# The public key of the peer to connect to (ie. the wireguard server):
WG_PEER_PUBLIC_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# The preshared key provided by the wireguard server:
WG_PEER_PRESHARED_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# The domain name and public wireguard port (UDP) of the public wireguard server
WG_PEER_ENDPOINT=wireguard.example.com:51820
# The IP addresses that are allowed to traverse the VPN (0.0.0.0/0 means ALL traffic)
WG_PEER_ALLOWED_IPS=0.0.0.0/0
# The interval in seconds to send keep-alive pings to the server (0 means OFF):
WG_PERSISTENT_KEEPALIVE=0
# ..End setup

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
       allowed-ips ${WG_PEER_ALLOWED_IPS} \
       persistent-keepalive ${WG_PERSISTENT_KEEPALIVE}

    ## Bring up the interface:
    ip link set ${WG_INTERFACE} up

    ## Remove the temporary files:
    rm -f ${TMP_PRIVATE_KEYFILE} ${TMP_PEER_PRESHARED_KEYFILE}

    ## Set rule-based routing (https://www.wireguard.com/netns/#the-classic-solutions)
    wg set ${WG_INTERFACE} fwmark 1234
    ip route add default dev ${WG_INTERFACE} table 2468
    ip rule add not fwmark 1234 table 2468
    ip rule add table main suppress_prefixlength 0
    
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

if [[ $UID != 0 ]]; then
    ## Automatically rerun this script as root:
    exec sudo -E "$(readlink -f "$0")" "$@"
else
    if [[ $# == 0 ]]; then
        usage
    fi
    command="$1"
    shift
    ## Command argument:
    case "$command" in
        up) up "$@" ;;
        down) down "$@" ;;
        *) usage;;
    esac
fi
