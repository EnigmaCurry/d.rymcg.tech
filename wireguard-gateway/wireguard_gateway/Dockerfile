# syntax=docker/dockerfile:1.9
FROM alpine:3.20

# Packages:
# - wireguard-tools: wg, wg-quick
# - iproute2: ip, tc
# - nftables/iptables: firewall/NAT (iptables only for TCPMSS clamp helper)
# - openresolv: resolvconf support (wg-quick DNS=)
# - dumb-init: proper PID 1 signal handling
# - curl,bash,tcpdump: useful for debugging
RUN apk add --no-cache \
    wireguard-tools iproute2 nftables iptables \
    openresolv dumb-init curl bash ca-certificates tcpdump

# Runtime env defaults (can override via compose/env)
ENV LAN_IF=eth0 \
    WG_IF=wg0 \
    WG_CONF=wg0 \
    CLAMP_MSS=true \
    NFT_ENABLE=true

# Expect /etc/wireguard/wg0.conf to be mounted (or COPY it in your build)
# COPY wg0.conf /etc/wireguard/wg0.conf

# Copy DHCP config
COPY udhcpc.conf /etc/udhcpc/udhcpc.conf

# Copy external entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=5 \
  CMD wg show >/dev/null 2>&1 || exit 1

ENTRYPOINT ["/usr/bin/dumb-init","--"]
CMD ["/usr/local/bin/entrypoint.sh"]
