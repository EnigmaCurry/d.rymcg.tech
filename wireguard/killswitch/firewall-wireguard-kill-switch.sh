#!/usr/bin/env bash
#====================================================================
# firewall-wireguard-kill-switch.sh
#
# Install a “kill‑switch” for a WireGuard Docker container:
#   • Find *all* IPv4 addresses that the container owns (except the
#     interface you want to keep alive and the loopback interface).
#   • For each of those source addresses: allow only traffic to the
#     CIDR(s) you give, and drop everything else.
#
# The allowed CIDR(s) are now taken from the container's
#   /config/<IFACE>.conf  file.  The script extracts the
#   `Endpoint = …` line, validates it and builds a /32 (IPv4) or
#   /128 (IPv6) CIDR that is used as the only egress destination.
#
# Usage:
#   sudo ./firewall-wireguard-kill-switch.sh <wireguard-instance>
#
#   <wireguard-instance>   Name of d.rymcg.tech wireguard instance
#                           (e.g., default, my-vpn, foo)
#====================================================================
set -euo pipefail

cd $(dirname ${BASH_SOURCE})
BIN=../../_scripts
source ${BIN}/funcs.sh

# -----------------------------------------------------------------
# Helper: print usage and exit
# -----------------------------------------------------------------
usage() {
    cat <<EOF
Usage:
  sudo $0 <wireguard-instance>
  <wireguard-instance>        Name of wireguard instance (e.g., default, my-vpn)
Example:
  sudo $0 my-vpn
EOF
    exit 1
}

# -----------------------------------------------------------------
# Helper: abort with a message
# -----------------------------------------------------------------
fail() {
    echo "❌ $*" >&2
    exit 1
}

# -----------------------------------------------------------------
# Argument handling
# -----------------------------------------------------------------
if (( $# < 1 )); then
    usage
fi
CONTAINER="wireguard_${1}-wireguard-1"
shift

# -----------------------------------------------------------------
# Hard‑coded values (feel free to edit)
# -----------------------------------------------------------------
IFACE=wg0                         # WireGuard interface that must stay up
CONF_PATH="/config/wg_confs/${IFACE}.conf"   # Path *inside* the container

# -----------------------------------------------------------------
# 0️⃣ Grab the list of CIDR(s) we are allowed to talk to
# -----------------------------------------------------------------
# The config file is a classic INI file.  We need the line that starts
# with “Endpoint =”.  The endpoint can be:
#   • IPv4  → 203.0.113.45:51820
#   • IPv6  → [2001:db8::1]:51820
# After stripping the port (and optional brackets) we turn the IP into
# a CIDR: /32 for IPv4, /128 for IPv6.
#
if ! ENDPOINT_LINE=$(docker exec "$CONTAINER" cat "$CONF_PATH" 2>/dev/null |
                    grep -i '^Endpoint[[:space:]]*=' || true); then
    fail "Could not read $CONF_PATH inside container '$CONTAINER'."
fi

if [[ -z $ENDPOINT_LINE ]]; then
    fail "No \"Endpoint = …\" line found in $CONF_PATH inside container '$CONTAINER'."
fi

# Extract the value after the first "=" and strip whitespace.
ENDPOINT_RAW=$(echo "$ENDPOINT_LINE" | cut -d= -f2- | tr -d '[:space:]')

# Remove optional surrounding [] (IPv6) and the trailing :PORT part.
#   203.0.113.45:51820   → 203.0.113.45
#   [2001:db8::1]:51820 → 2001:db8::1
ENDPOINT_IP=$(echo "$ENDPOINT_RAW" | sed -E 's/^\[?([^]]+)\]?:[0-9]+$/\1/')

# Validate that the extracted string is a real IP address.
if ! validate_ip_address "$ENDPOINT_IP"; then
    fail "Extracted endpoint \"$ENDPOINT_IP\" is not a valid IP address."
fi

# Turn the IP into a CIDR (the nft matcher expects CIDR notation).
if [[ "$ENDPOINT_IP" == *.* ]]; then
    ENDPOINT_CIDR="${ENDPOINT_IP}/32"
else
    ENDPOINT_CIDR="${ENDPOINT_IP}/128"
fi

# Double‑check the resulting CIDR syntax (just in case).
if ! validate_ip_network "$ENDPOINT_CIDR"; then
    fail "Generated CIDR \"$ENDPOINT_CIDR\" is not valid."
fi

# Put the (single) CIDR into the array the rest of the script expects.
ALLOWED_CIDRS=("$ENDPOINT_CIDR")

# -----------------------------------------------------------------
# 1️⃣ Gather *all* IPv4 addresses of the container, then filter.
# -----------------------------------------------------------------
# `ip -4 -o addr show` prints one line per IPv4 address:
#   2: eth0 inet 172.20.0.5/16 brd 172.20.255.255 scope global eth0
#   3: eth1 inet 10.1.2.3/24   brd 10.1.2.255 scope global eth1
#   1: lo   inet 127.0.0.1/8   scope host lo
#
# Keep every address whose *interface* is NOT $IFACE and NOT lo.
readarray -t ALL_IPV4 < <(
    docker exec "$CONTAINER" ip -4 -o addr show |
    awk '$2 != "lo" && $2 != "'"$IFACE"'" {print $4}'   # $4 = "IP/prefix"
)
if (( ${#ALL_IPV4[@]} == 0 )); then
    echo "⚠️  No extra IPv4 addresses found on container '$CONTAINER' (apart from $IFACE and lo)."
    echo "    Nothing to block – exiting."
    exit 0
fi

# Strip the prefix length – we only need the plain address for matching.
SRC_IPS=()
for entry in "${ALL_IPV4[@]}"; do
    SRC_IPS+=( "${entry%%/*}" )
done

# -----------------------------------------------------------------
# 2️⃣ Build the nft commands (only echo, no execution)
# -----------------------------------------------------------------
TABLE="inet kill_switch"
CHAIN="container_${CONTAINER}_egress"

# Helper: join CIDR list with commas for nft syntax.
join_by_comma() {
    local IFS=,
    echo "$*"
}
ALLOWED_SET=$(join_by_comma "${ALLOWED_CIDRS[@]}")

cat <<EOS
# -----------------------------------------------------------------
# KILL‑SWITCH for WireGuard container  : $CONTAINER
# All packets not going through the wireguard peer will be dropped!
# Container interface that stays open  : $IFACE
# Source IPs that will be filtered     : ${SRC_IPS[*]}
# Allowed egress CIDR(s)               : ${ALLOWED_CIDRS[*]}
# Run the following commands on the Docker HOST (pipe this output to bash).
# -----------------------------------------------------------------
sudo nft add table $TABLE 2>/dev/null || true
sudo nft add chain $TABLE $CHAIN { type filter hook forward priority 0 \; } 2>/dev/null || true
sudo nft flush chain $TABLE $CHAIN
EOS

# Emit the rule pair for each source address we want to lock down.
for ip in "${SRC_IPS[@]}"; do
    cat <<EOS
sudo nft add rule $TABLE $CHAIN ip saddr $ip ip daddr { $ALLOWED_SET } accept
sudo nft add rule $TABLE $CHAIN ip saddr $ip drop
EOS
done

# cat <<'EOS'
# # -----------------------------------------------------------------
# # OPTIONAL: If you want the chain to be reachable from the *global* FORWARD chain
# # (instead of being a separate table that Docker never jumps into), uncomment:
# # sudo nft insert rule ip filter FORWARD jump $TABLE $CHAIN
# # -----------------------------------------------------------------
# EOS
