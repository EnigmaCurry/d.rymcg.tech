#!/usr/bin/env bash
#====================================================================
# firewall-container-killswitch.sh
#
# Install a “kill‑switch” for a Docker container:
#   • Find *all* IPv4 addresses that the container owns (except the
#     interface you want to keep alive and the loopback interface).
#   • For each of those source addresses: allow only traffic to the
#     CIDR(s) you give, and drop everything else.
#
# Usage:
#   sudo ./firewall-container-killswitch.sh <container> [<interface>] <allowed-CIDR> [...]
#
#   <container>            Docker container name or ID
#   <interface> (optional) Interface inside the container that you
#                          *do not* want to block (default: eth0)
#   <allowed-CIDR>         One or more CIDR blocks that are allowed
#                          for egress.
#====================================================================

set -euo pipefail

# -----------------------------------------------------------------
# Helper: print usage and exit
# -----------------------------------------------------------------
usage() {
    cat <<EOF
Usage:
  sudo $0 <container> [<interface>] <allowed-CIDR> [...]

  <container>            Docker container name or ID
  <interface> (optional) Interface inside the container that should
                         remain unrestricted (default: eth0)
  <allowed-CIDR>         One or more CIDR ranges (e.g. 203.0.113.10/32)

Example:
  sudo $0 wireguard eth0 203.0.113.10/32 198.51.100.0/24
EOF
    exit 1
}

# -----------------------------------------------------------------
# Argument handling
# -----------------------------------------------------------------
if (( $# < 2 )); then
    usage
fi

CONTAINER=$1
shift

# Detect whether the next argument is an interface name.
# If it contains a '/' or a '.' we assume it is a CIDR, otherwise an iface.
if [[ "$1" != *"/"* && "$1" != *"."* ]]; then
    IFACE=$1
    shift
else
    IFACE="eth0"
fi

ALLOWED_CIDRS=("$@")
if (( ${#ALLOWED_CIDRS[@]} == 0 )); then
    echo "Error: you must specify at least one allowed CIDR."
    usage
fi

# -----------------------------------------------------------------
# 1️⃣  Gather *all* IPv4 addresses of the container, then filter.
# -----------------------------------------------------------------
# Run inside the container: `ip -4 -o addr show` gives one‑line per address:
#   2: eth0    inet 172.20.0.5/16 brd 172.20.255.255 scope global eth0
#   3: eth1    inet 10.1.2.3/24   brd 10.1.2.255 scope global eth1
#   1: lo      inet 127.0.0.1/8   scope host lo
#
# We keep every address whose *interface* is NOT $IFACE and NOT lo.

readarray -t ALL_IPV4 < <(
    docker exec "$CONTAINER" ip -4 -o addr show |
    awk '$2 != "lo" && $2 != "'"$IFACE"'" {print $4}'   # $4 = "IP/prefix"
)

if (( ${#ALL_IPV4[@]} == 0 )); then
    echo "Warning: no extra IPv4 addresses found on container '$CONTAINER' (apart from $IFACE and lo)."
    echo "Nothing to block – exiting."
    exit 0
fi

# Strip the prefix length, we only need the plain address for matching.
SRC_IPS=()
for entry in "${ALL_IPV4[@]}"; do
    SRC_IPS+=( "${entry%%/*}" )
done

# -----------------------------------------------------------------
# 2️⃣  Build the nft commands (only echo, no execution)
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
# KILL‑SWITCH for Docker container : $CONTAINER
# Interface that stays open          : $IFACE
# Source IPs that will be filtered  : ${SRC_IPS[*]}
# Allowed egress CIDR(s)            : ${ALLOWED_CIDRS[*]}
# -----------------------------------------------------------------
# 1️⃣  Create (or reuse) table
sudo nft add table $TABLE 2>/dev/null || true

# 2️⃣  Create a dedicated chain to match forwarded packets
sudo nft add chain $TABLE $CHAIN { type filter hook forward priority 0 \; } 2>/dev/null || true

# 3️⃣  Flush any old rules that may belong to a previous run for this container
sudo nft flush chain $TABLE $CHAIN

EOS

# Emit the rule pair for each source address we want to lock down.
for ip in "${SRC_IPS[@]}"; do
    cat <<EOS
# ---- Rules for source $ip ----
#   Allow traffic to the whitelisted CIDR(s)
sudo nft add rule $TABLE $CHAIN ip saddr $ip ip daddr { $ALLOWED_SET } accept

#   Drop everything else that originates from $ip
sudo nft add rule $TABLE $CHAIN ip saddr $ip drop
EOS
done

cat <<'EOS'

# -----------------------------------------------------------------
# OPTIONAL: If you want the chain to be reachable from the *global* FORWARD chain
# (instead of being a separate table that Docker never jumps into), uncomment:
# sudo nft insert rule ip filter FORWARD jump $TABLE $CHAIN
# -----------------------------------------------------------------
EOS
