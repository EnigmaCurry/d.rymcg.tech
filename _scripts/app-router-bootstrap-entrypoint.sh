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
    if command -v iptables >/dev/null 2>&1; then
        iptables "$@"
    elif command -v iptables-legacy >/dev/null 2>&1; then
        iptables-legacy "$@"
    else
        log "ERROR: iptables command not found"
        exit 1
    fi
}
ip6tables_cmd() {
    if command -v ip6tables >/dev/null 2>&1; then
        ip6tables "$@"
    elif command -v ip6tables-legacy >/dev/null 2>&1; then
        ip6tables-legacy "$@"
    else
        log "ERROR: ip6tables command not found"
        exit 1
    fi
}

split_comma_list() {
    src=$1                     # e.g. DOCKER_GATEWAY_PORTS
    eval "list=\${$src-}"
    [ -z "$list" ] && return
    IFS=,
    set -- $list               # now $1 $2 … are the individual fields
    IFS=' '
    printf '%s' "$*"
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
    if [ -n "$CURRENT_GW4" ]; then
        log "Adding IPv4 black‑hole rule for $CURRENT_GW4"
        iptables_cmd -I OUTPUT -d "$CURRENT_GW4/32" -j DROP   || true
        iptables_cmd -I FORWARD -d "$CURRENT_GW4/32" -j DROP || true
        iptables_cmd -I OUTPUT -d "$CURRENT_GW4/32" -m conntrack \
                     --ctstate ESTABLISHED,RELATED -j ACCEPT
        iptables_cmd -I INPUT  -s "$CURRENT_GW4/32" -m conntrack \
                     --ctstate ESTABLISHED,RELATED -j ACCEPT
        _ports=$(split_comma_list DOCKER_GATEWAY_PORTS)
        for _port in "$_ports"; do
            [ -z "$_port" ] && continue
            iptables_cmd -I INPUT -s "$CURRENT_GW4/32" -p tcp \
                         --dport "$_port" -j ACCEPT
        done
    fi

    if [ -n "$CURRENT_GW6" ]; then
        log "Adding IPv6 black‑hole rule for $CURRENT_GW6"
        ip6tables_cmd -I OUTPUT -d "$CURRENT_GW6/128" -j DROP   || true
        ip6tables_cmd -I FORWARD -d "$CURRENT_GW6/128" -j DROP || true
        ip6tables_cmd -I OUTPUT -d "$CURRENT_GW6/128" -m conntrack \
                      --ctstate ESTABLISHED,RELATED -j ACCEPT
        ip6tables_cmd -I INPUT  -s "$CURRENT_GW6/128" -m conntrack \
                      --ctstate ESTABLISHED,RELATED -j ACCEPT
        _ports=$(split_comma_list DOCKER_GATEWAY_PORTS)
        for _port in "$_ports"; do
            [ -z "$_port" ] && continue
            ip6tables_cmd -I INPUT -s "$CURRENT_GW6/128" -p tcp \
                          --dport "$_port" -j ACCEPT
        done
    fi

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

    # ---------------------------------------------------------------
    #  sanity‑check – verify that the old gateway is really unreachable
    # ---------------------------------------------------------------
    if [ -n "$CURRENT_GW4" ]; then
        if command -v ping >/dev/null 2>&1; then
            if ping -c 1 -W 1 "$CURRENT_GW4" >/dev/null 2>&1 \
                    || ping -c 1 -w 1 "$CURRENT_GW4" >/dev/null 2>&1; then
                log "ERROR: old IPv4 gateway $CURRENT_GW4 is still reachable – DROP rule may not be effective"
                exit 1
            fi
        else
            log "ERROR: ping command not found – cannot verify reachability of old IPv4 gateway $CURRENT_GW4"
            exit 1
        fi
    fi

    if [ -n "$CURRENT_GW6" ]; then
        if command -v ping6 >/dev/null 2>&1; then
            if ping6 -c 1 -W 1 "$CURRENT_GW6" >/dev/null 2>&1 \
                    || ping6 -c 1 -w 1 "$CURRENT_GW6" >/dev/null 2>&1; then
                log "ERROR: old IPv6 gateway $CURRENT_GW6 is still reachable – DROP rule may not be effective"
                exit 1
            fi
        elif command -v ping >/dev/null 2>&1 && ping -6 -c 1 -W 1 "$CURRENT_GW6" >/dev/null 2>&1; then
            # Some images only ship a single `ping` that also supports the -6 flag
            log "ERROR: old IPv6 gateway $CURRENT_GW6 is still reachable – DROP rule may not be effective"
            exit 1
        else
            log "ERROR: IPv6 ping command not found – cannot verify reachability of old IPv6 gateway $CURRENT_GW6"
            exit 1
        fi
    fi
    echo "### INFO: Modification of routing table complete."
else
    echo "### INFO: using default container gateway routes."
fi

## ENTRYPOINT may be provided by the environment, if not, construct a
## shell script containining the original entrypoint and command:
if [ -z "${ENTRYPOINT:-}" ]; then
    # -------------------------------------------------
    # Build a *temporary* shell script that runs $@
    # -------------------------------------------------
    tmpfile=$(mktemp /tmp/run-cmd.XXXXXX.sh)

    cat >"$tmpfile" <<'EOF'
#!/bin/sh
CMD_LINE_PLACEHOLDER
EOF

    # Replace the placeholder with the *exact* command line we received.
    # Using printf %s … ensures that we don’t lose any characters.
    # We also escape any single‑quotes that might be inside the arguments.
    escaped_cmd=$(printf "%s" "$*" | sed "s/'/'\\\\''/g")
    # The result is a single‑quoted string that the shell will interpret correctly.
    # (If you don’t need quoting at all you can simply use: echo "$*" >"$tmpfile")
    sed -i "s|CMD_LINE_PLACEHOLDER|exec $escaped_cmd|g" "$tmpfile"
    chmod +x "$tmpfile"
    ENTRYPOINT="$tmpfile"
fi

# -------------------------------------------------
# Drop capabilities and exec the temporary script
# -------------------------------------------------
exec capsh --drop=cap_net_admin -- "${ENTRYPOINT}"
