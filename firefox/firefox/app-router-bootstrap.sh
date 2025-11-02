#!/usr/bin/env sh
set -ex

: "${ROUTER_IPV4:?ROUTER_IPV4 environment variable is required}"
: "${ROUTER_IPV6:?ROUTER_IPV6 environment variable is required}"

ip route del default || true
ip -6 route del default || true
ip route add default via "$ROUTER_IPV4"
ip -6 route add default via "$ROUTER_IPV6"

## Drop capabilities

## Run Linuxserver specific /init entrypoint:
exec capsh --drop=cap_net_admin -- -c "/init"
