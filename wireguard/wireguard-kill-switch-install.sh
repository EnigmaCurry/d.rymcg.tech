#!/usr/bin/env bash
#====================================================================
# wireguard-kill-switch-install.sh
#====================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${SCRIPT_DIR}/../../_scripts"
[ -f "${BIN}/funcs.sh" ] && source "${BIN}/funcs.sh"

usage() {
    cat <<EOF
Usage:
  DOCKER_CONTEXT=<ssh-host> $0 <wireguard-instance>
  $0 --host <ssh-host> <wireguard-instance>

Examples:
  DOCKER_CONTEXT=docker-vm $0 default
  $0 --host docker@10.0.0.5 mullvad
EOF
    exit 1
}

# ------ CLI --------------------------------------------------------
REMOTE_HOST="${DOCKER_CONTEXT:-}"
if [[ $# -ge 1 && "$1" == "--host" ]]; then
    shift
    REMOTE_HOST="$1"
    shift
fi

if [[ -z "${REMOTE_HOST}" ]]; then
    echo "❌ Need remote host. Set DOCKER_CONTEXT=... or use --host <ssh-host>."
    usage
fi

if (( $# < 1 )); then
    usage
fi

WG_INSTANCE="$1"
CONTAINER="wireguard_${WG_INSTANCE}-wireguard-1"

# ------ constants --------------------------------------------------
IFACE="wg0"
CONF_PATH="/config/wg_confs/${IFACE}.conf"

# ==================================================================
# 0️⃣ Read endpoint from inside the container
# ==================================================================
ENDPOINT_LINE=$(
    docker exec "$CONTAINER" cat "$CONF_PATH" 2>/dev/null | \
    grep -i '^Endpoint[[:space:]]*=' || true
)
if [[ -z "${ENDPOINT_LINE}" ]]; then
    echo "❌ No \"Endpoint = ...\" line found in ${CONF_PATH} inside container '${CONTAINER}'" >&2
    exit 1
fi

ENDPOINT_RAW=$(echo "${ENDPOINT_LINE}" | cut -d= -f2- | tr -d '[:space:]')
ENDPOINT_IP=$(echo "${ENDPOINT_RAW}" | sed -E 's/^\[?([^]]+)\]?:[0-9]+$/\1/')

if declare -F validate_ip_address >/dev/null 2>&1; then
    if ! validate_ip_address "${ENDPOINT_IP}"; then
        echo "❌ Extracted endpoint '${ENDPOINT_IP}' is not a valid IP." >&2
        exit 1
    fi
fi

if [[ "${ENDPOINT_IP}" == *.* ]]; then
    ENDPOINT_CIDR="${ENDPOINT_IP}/32"
else
    ENDPOINT_CIDR="${ENDPOINT_IP}/128"
fi

echo "## Retrieving container network information ..."

# ==================================================================
# 1️⃣ Get all extra IPv4 addresses from the container
# ==================================================================
readarray -t ALL_IPV4 < <(
    docker exec "$CONTAINER" ip -4 -o addr show |
    awk '$2 != "lo" && $2 != "'"$IFACE"'" {print $4}'
)

if (( ${#ALL_IPV4[@]} == 0 )); then
    echo "⚠️  No extra IPv4 addresses found on container '$CONTAINER' (only lo / $IFACE). Nothing to install."
    exit 0
else
    echo "## Found all IPv4 addresses"
fi

SRC_IPS=()
for entry in "${ALL_IPV4[@]}"; do
    SRC_IPS+=( "${entry%%/*}" )
done

# ==================================================================
# 2️⃣ Build the remote script (this is what systemd will run)
# ==================================================================
echo "## Build nft script"

TABLE="d_rymcg_tech_wireguard_kill_switch"
CHAIN="container_${CONTAINER}_egress"
ALLOWED_SET="${ENDPOINT_CIDR}"

REMOTE_NFT_SCRIPT="$(cat <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
# Auto-generated kill-switch for container: ${CONTAINER}

# 1. create (or reuse) table
nft add table inet ${TABLE} 2>/dev/null || true

# 2. create (or reuse) chain with forward hook
nft add chain inet ${TABLE} ${CHAIN} '{ type filter hook forward priority 0 ; }' 2>/dev/null || true

# 3. flush old rules for this container so re-runs are clean
nft flush chain inet ${TABLE} ${CHAIN}
EOF
)"

# add the rule pairs
for ip in "${SRC_IPS[@]}"; do
    REMOTE_NFT_SCRIPT+=$'\n'"nft add rule inet ${TABLE} ${CHAIN} ip saddr ${ip} ip daddr { ${ALLOWED_SET} } accept"
    REMOTE_NFT_SCRIPT+=$'\n'"nft add rule inet ${TABLE} ${CHAIN} ip saddr ${ip} drop"
done

echo "## Script built."

# ==================================================================
# 3️⃣ systemd unit
# ==================================================================
echo "## Preparing systemd unit"
REMOTE_UNIT_TEMPLATE="$(cat <<'UNIT'
[Unit]
Description=WireGuard Docker kill-switch for %i
After=network-online.target firewalld.service docker.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/wg-killswitch-%i.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT
)"

# ==================================================================
# 4️⃣ Ship to remote
# ==================================================================
REMOTE_SCRIPT_PATH="/usr/local/sbin/wg-killswitch-${CONTAINER}.sh"
REMOTE_UNIT_PATH="/etc/systemd/system/wg-killswitch@.service"
REMOTE_INSTANCE="wg-killswitch@${CONTAINER}.service"

echo "==> Installing kill-switch for ${CONTAINER} on ${REMOTE_HOST} ..."
ssh "${REMOTE_HOST}" sudo mkdir -p /usr/local/sbin

echo "==> Uploading nft script to ${REMOTE_HOST}:${REMOTE_SCRIPT_PATH}"
ssh "${REMOTE_HOST}" "sudo tee ${REMOTE_SCRIPT_PATH} >/dev/null" <<< "${REMOTE_NFT_SCRIPT}"
ssh "${REMOTE_HOST}" "sudo chmod 0755 ${REMOTE_SCRIPT_PATH}"

echo "==> Uploading systemd template to ${REMOTE_HOST}:${REMOTE_UNIT_PATH}"
ssh "${REMOTE_HOST}" "sudo tee ${REMOTE_UNIT_PATH} >/dev/null" <<< "${REMOTE_UNIT_TEMPLATE}"

echo "==> Enabling and starting ${REMOTE_INSTANCE} on ${REMOTE_HOST}"
ssh "${REMOTE_HOST}" "sudo systemctl daemon-reload"
ssh "${REMOTE_HOST}" "sudo systemctl enable --now ${REMOTE_INSTANCE}"
echo
ssh "${REMOTE_HOST}" "sudo systemctl status ${REMOTE_INSTANCE}"
echo
echo "## Here is the kill-switch that will be automatically applied for this instance (${WG_INSTANCE}):"
ssh "${REMOTE_HOST}" "sudo nft list chain inet kill_switch ${CHAIN}"
echo
echo "## ✅ kill-switch installed. The remote service should now re-apply the nft rules automatically on boot."
