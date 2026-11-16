#!/bin/sh
set -e

TLS_MODE="${TLS_MODE:-traefik}"
case "${TLS_MODE}" in
    traefik|passthrough) ;;
    *) echo "Invalid TLS_MODE: ${TLS_MODE} (must be 'traefik' or 'passthrough')" >&2; exit 1 ;;
esac

# Generate the Caddyfile
envsubst < /etc/caddy/Caddyfile.${TLS_MODE}.template > /etc/caddy/Caddyfile

echo "TLS_MODE=${TLS_MODE}"
echo "Caddyfile:"
echo
cat /etc/caddy/Caddyfile
echo

# Exec into the real Caddy process
exec "$@"
