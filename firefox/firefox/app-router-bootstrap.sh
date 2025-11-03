#!/usr/bin/env sh
set -ex

: "${WIREGUARD_ROUTER_IPV4:?WIREGUARD_ROUTER_IPV4 environment variable is required}"
: "${WIREGUARD_ROUTER_IPV6:?WIREGUARD_ROUTER_IPV6 environment variable is required}"

ip route del default || true
ip -6 route del default || true
ip route add default via "$WIREGUARD_ROUTER_IPV4"
ip -6 route add default via "$WIREGUARD_ROUTER_IPV6"

## Drop capabilities

## Run Linuxserver specific /init entrypoint:
exec capsh --drop=cap_net_admin -- -c "/init"
