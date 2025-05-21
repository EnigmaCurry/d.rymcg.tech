#!/bin/sh
set -e

# Generate the Caddyfile
envsubst < /etc/caddy/Caddyfile.template > /etc/caddy/Caddyfile

echo "Caddyfile:"
echo
cat /etc/caddy/Caddyfile
echo

# Exec into the real Caddy process
exec "$@"
