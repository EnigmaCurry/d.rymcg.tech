#!/bin/sh
set -eu

log() { printf '%s %s\n' "[config]" "$*"; }
die() { printf '%s %s\n' "[config][ERROR]" "$*" >&2; exit 1; }

INSPIRCD_CFG_DIR="/inspircd/conf.d"
ANOPE_CFG_DIR="/anope"
MSMTPRC="${ANOPE_CFG_DIR}/msmtprc"

: "${RELAY_HOST:=postfix-relay}"
: "${RELAY_PORT:=25}"
: "${MAIL_FROM:=noreply@${INSP_SERVER_HOSTNAME}${INSP_NET_SUFFIX}}"

[ -d "$INSPIRCD_CFG_DIR" ] || die "INSPIRCD_CFG_DIR doesn't exist: $INSPIRCD_CFG_DIR"
[ -w "$INSPIRCD_CFG_DIR" ] || die "config dir not writable: $INSPIRCD_CFG_DIR (is the volume mounted?)"
[ -d "$ANOPE_CFG_DIR" ] || die "ANOPE_CFG_DIR doesn't exist: $ANOPE_CFG_DIR"
[ -w "$ANOPE_CFG_DIR" ] || die "config dir not writable: $ANOPE_CFG_DIR (is the volume mounted?)"

cat <<EOF > ${INSPIRCD_CFG_DIR}/traefik_proxy.conf
<module name="haproxy">
<bind address="" port="6668" type="clients" hook="haproxy">
EOF

chown -R 10000:10000 /inspircd/conf.d
ls -lha /inspircd/conf.d

umask 077
cat > "$MSMTPRC" <<EOF
defaults
auth off
tls off
logfile /dev/stdout

account relay
host ${RELAY_HOST}
port ${RELAY_PORT}
from ${MAIL_FROM}

account default : relay
EOF
chmod 600 "$MSMTPRC"
chown -R 10000:10000 "${MSMTPRC}"
ls -lha /anope

log "done."
exit 0
