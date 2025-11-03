#!/usr/bin/env sh
# ------------------------------------------------------------
#  App entrypoint to replace container's default route with a
#  wireguard instance, and to create a blackhole for the original
#  gateway router.
# ------------------------------------------------------------
#  1. Detect existing default gateways (IPv4/IPv6)
#  2. Insert DROP rules for those gateways (iptables/ip6tables)
#  3. Replace the default routes with the WG router addresses
#  4. Drop CAP_NET_ADMIN and exec the original /init
# ------------------------------------------------------------
set -eu   # abort on error, treat unset variables as fatal

log() {
    # Simple timestamped logger – goes to stdout (Docker will capture it)
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

iptables_cmd() {
    if command -v iptables-legacy >/dev/null 2>&1; then
        iptables-legacy "$@"
    elif command -v iptables >/dev/null 2>&1; then
        iptables "$@"
    else
        log "ERROR: iptables command not found"
        exit 1
    fi
}
ip6tables_cmd() {
    if command -v ip6tables-legacy >/dev/null 2>&1; then
        ip6tables-legacy "$@"
    elif command -v ip6tables >/dev/null 2>&1; then
        ip6tables "$@"
    else
        log "ERROR: ip6tables command not found"
        exit 1
    fi
}

if [ -n "${WIREGUARD_INSTANCE}" ]; then
    # -------------------------------------------------------------------------
    #  Grab the **current** default gateways (if any)
    # -------------------------------------------------------------------------
    #  IPv4
    CURRENT_GW4=$(ip route show default 2>/dev/null | awk '/default/ {print $3; exit}')
    #  IPv6
    CURRENT_GW6=$(ip -6 route show default 2>/dev/null | awk '/default/ {print $3; exit}')
    log "Detected current gateways:"
    log "  IPv4: ${CURRENT_GW4:-<none>}"
    log "  IPv6: ${CURRENT_GW6:-<none>}"

    # -------------------------------------------------------------------------
    #  Install black‑hole iptables rules for those gateways
    # -------------------------------------------------------------------------
    #  The rule is placed **before** any user‑defined rule so it wins.
    #  We use the OUTPUT chain (packets that the container itself generates).
    #  If you also want to block *forwarded* traffic you can add the same rule
    #  to the FORWARD chain.
    # -------------------------------------------------------------------------
    # if [ -n "$CURRENT_GW4" ]; then
    #     # Ensure we have the capability to touch iptables – we still have CAP_NET_ADMIN
    #     log "Adding IPv4 black‑hole rule for $CURRENT_GW4"
    #     iptables_cmd -I OUTPUT -d "$CURRENT_GW4/32" -j DROP || true
    #     # (Optional) also drop from FORWARD if the container ever becomes a router
    #     iptables_cmd -I FORWARD -d "$CURRENT_GW4/32" -j DROP || true
    # fi

    # if [ -n "$CURRENT_GW6" ]; then
    #     log "Adding IPv6 black‑hole rule for $CURRENT_GW6"
    #     ip6tables_cmd -I OUTPUT -d "$CURRENT_GW6/128" -j DROP || true
    #     ip6tables_cmd -I FORWARD -d "$CURRENT_GW6/128" -j DROP || true
    # fi
    ####        TODO
    ####  Have to find a way to block "internet" traffic without blocking Traefik.

    # -------------------------------------------------------------------------
    #  Replace the default routes with the WireGuard router ones
    # -------------------------------------------------------------------------
    : "${WIREGUARD_ROUTER_IPV4:?WIREGUARD_ROUTER_IPV4 environment variable is required}"
    : "${WIREGUARD_ROUTER_IPV6:?WIREGUARD_ROUTER_IPV6 environment variable is required}"

    # Delete any existing default routes (ignore errors if none exist)
    log "Removing any existing default routes"
    ip route del default 2>/dev/null || true
    ip -6 route del default 2>/dev/null || true

    # Add the new routes that point at the WG router
    log "Adding new default routes"
    ip route add default via "$WIREGUARD_ROUTER_IPV4"
    ip -6 route add default via "$WIREGUARD_ROUTER_IPV6"

    log "Routes after modification:"
    log "  IPv4: $(ip route show default || echo '<none>')"
    log "  IPv6: $(ip -6 route show default || echo '<none>')"

    # -------------------------------------------------------------------------
    #  sanity‑check – make sure we *did* replace the old gateway
    # -------------------------------------------------------------------------
    # This is defensive; if something went wrong we fall back to the original
    # behaviour (just delete the route and continue).  It does **not** abort the
    # container – the route change itself is already done above.
    if [ -n "$CURRENT_GW4" ]; then
        if ip route get "$CURRENT_GW4" >/dev/null 2>&1; then
            log "WARN: traffic to old IPv4 gateway $CURRENT_GW4 may still be reachable (no DROP rule applied?)"
        fi
    fi
    if [ -n "$CURRENT_GW6" ]; then
        if ip -6 route get "$CURRENT_GW6" >/dev/null 2>&1; then
            log "WARN: traffic to old IPv6 gateway $CURRENT_GW6 may still be reachable (no DROP rule applied?)"
        fi
    fi
else
    echo "### INFO: using default container gateway routes."
fi


# -------------------------------------------------------------------------
#  Drop the privileged capability and exec the original init
# -------------------------------------------------------------------------
log "Dropping CAP_NET_ADMIN and handing over to /init"
# The container originally needed CAP_NET_ADMIN for `ip route …` and `iptables …`.
# After we are finished we drop it so the rest of the container runs with the
# least privileges possible.
exec capsh --drop=cap_net_admin -- -c "/init"
