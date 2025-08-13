#!/usr/bin/env bash
set -exuo pipefail

LAN_IF="${WIREGUARD_GATEWAY_LAN_INTERFACE:-eth0}"
WG_IF="${WIREGUARD_GATEWAY_VPN_INTERFACE:-wg0}"
WG_CONF="${WG_CONF:-${WG_IF}}"
NFT_ENABLE="${NFT_ENABLE:-true}"
CLAMP_MSS="${CLAMP_MSS:-true}"

echo "[init] starting wg-gw (LAN_IF=${LAN_IF}, WG_IF=${WG_IF})"

# Ensure LAN_IF exists
if ! ip link show "$LAN_IF" >/dev/null 2>&1; then
  echo "[error] LAN interface '$LAN_IF' not found" >&2
  exit 1
fi

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

# nftables NAT + forward
if [ "${NFT_ENABLE}" = "true" ]; then
  echo "[nft] applying rules (masquerade out ${WG_IF})"
  cat >/etc/nftables.conf <<NFT
flush ruleset
table inet fw {
  chain forward {
    type filter hook forward priority 0;
    policy drop;

    iifname "${LAN_IF}" oifname "${WG_IF}" accept
    ct state related,established accept
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
