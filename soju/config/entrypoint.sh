#!/bin/sh
set -eu

log() { printf '%s %s\n' "[config]" "$*"; }
die() { printf '%s %s\n' "[config][ERROR]" "$*" >&2; exit 1; }

CFG_DIR="/etc/soju"
CFG_PATH="$CFG_DIR/config"
DATA_ROOT="/var/lib/soju"

[ -d "$CFG_DIR" ] || mkdir -p "$CFG_DIR" || die "cannot mkdir $CFG_DIR"
[ -w "$CFG_DIR" ] || die "config dir not writable: $CFG_DIR (is the volume mounted?)"

cat <<EOF > ${CFG_PATH}
listen irc+insecure://0.0.0.0:6697
listen unix+admin://
hostname ${TRAEFIK_HOST}
title "${TITLE}"
auth internal
accept-proxy-ip localhost
db sqlite3 ${DATA_ROOT}/main.db
message-store fs ${DATA_ROOT}/logs/
file-upload fs ${DATA_ROOT}/upload
motd ${CFG_DIR}/motd
EOF

cat ${CFG_PATH}
printf '%s' "$MOTD" > "${CFG_DIR}/motd"
log "done."
exit 0
