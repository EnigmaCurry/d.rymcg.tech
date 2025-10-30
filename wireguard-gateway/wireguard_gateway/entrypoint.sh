#!/usr/bin/env bash
set -exuo pipefail

LAN_IF="${LAN_INTERFACE}"
WG_IF="${VPN_INTERFACE}"
WG_CONF="${WG_CONF:-${WG_IF}}"
NFT_ENABLE="${NFT_ENABLE:-true}"
CLAMP_MSS="${CLAMP_MSS:-true}"

# New: comma-separated list like "10.0.0.0/24,192.168.1.0/24"
# Only way to allow all clients is "0.0.0.0/0"
CLIENT_ALLOWED_IPS="${CLIENT_ALLOWED_IPS:-}"

echo "[init] starting wg-gw (LAN_IF=${LAN_IF}, WG_IF=${WG_IF})"

# Ensure LAN_IF exists
if ! ip link show "$LAN_IF" >/dev/null 2>&1; then
  echo "[error] LAN interface '$LAN_IF' not found" >&2
  exit 1
fi

# Basic sanity for CLIENT_ALLOWED_IPS (require explicit allowlist)
if [ -z "${CLIENT_ALLOWED_IPS}" ]; then
  echo "[error] CLIENT_ALLOWED_IPS is required (comma-separated IPv4 CIDRs, e.g. '10.0.0.0/24,192.168.1.0/24' or '0.0.0.0/0')" >&2
  exit 1
fi

if [ -z "${LAN_IF}" ]; then
  echo "[error] LAN_IF is required" >&2
  exit 1
fi

if [ -z "${WG_IF}" ]; then
  echo "[error] WG_IF is required" >&2
  exit 1
fi

# Normalize CLIENT_ALLOWED_IPS -> nft set elements
# (simple format check; assumes valid CIDRs)
IFS=', ' read -r -a _cidrs <<< "${CLIENT_ALLOWED_IPS}"
ALLOWED_ELEMENTS=""
for cidr in "${_cidrs[@]}"; do
  [ -z "${cidr:-}" ] && continue
  cidr="${cidr//[[:space:]]/}"
  if [[ ! "$cidr" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
    echo "[error] invalid IPv4 CIDR in CLIENT_ALLOWED_IPS: '$cidr'" >&2
    exit 1
  fi
  ALLOWED_ELEMENTS+="${ALLOWED_ELEMENTS:+, }${cidr}"
done
if [ -z "${ALLOWED_ELEMENTS}" ]; then
  echo "[error] CLIENT_ALLOWED_IPS produced an empty allowlist" >&2
  exit 1
fi
echo "[policy] allowing LAN sources: { ${ALLOWED_ELEMENTS} }"

# DHCP lease on LAN IF; -R prevents touching /etc/resolv.conf (bind-mounted in Docker)
echo "[dhcp] requesting lease on ${LAN_IF}..."
udhcpc -i "$LAN_IF" -f -q -n || echo "[warn] DHCP failed; continuing if an address already exists"

# Bring up WireGuard
if [ ! -f "/etc/wireguard/${WG_CONF}.conf" ]; then
  echo "[error] /etc/wireguard/${WG_CONF}.conf is missing" >&2
  exit 1
fi
echo "[wg] bringing up ${WG_CONF}..."
wg-quick up "${WG_CONF}"

# nftables NAT + forward with source allowlist
if [ "${NFT_ENABLE}" = "true" ]; then
  echo "[nft] applying rules (masquerade out ${WG_IF}, restrict LAN sources)"
  cat >/etc/nftables.conf <<NFT
flush ruleset
table inet fw {
  set allowed_clients_v4 {
    type ipv4_addr
    flags interval
    elements = { ${ALLOWED_ELEMENTS} }
  }

  chain forward {
    type filter hook forward priority 0;
    policy drop;

    # Always allow replies
    ct state established,related accept

    # Only allow LAN->WG if source is in allowed set
    iifname "${LAN_IF}" oifname "${WG_IF}" ip saddr @allowed_clients_v4 accept
  }

  chain postrouting {
    type nat hook postrouting priority 100;
    oifname "${WG_IF}" masquerade
  }
}
NFT
  nft -f /etc/nftables.conf
else
  echo "[nft] skipped (NFT_ENABLE=false)"
fi

# Optional MSS clamp to avoid PMTU issues through WG
if [ "${CLAMP_MSS}" = "true" ]; then
  echo "[mss] enabling TCPMSS clamp on ${WG_IF}"
  iptables -t mangle -A FORWARD -o "${WG_IF}" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu || true
fi

echo "[ready] WireGuard gateway is up"
wg show

# Keep container in foreground
exec tail -f /dev/null
