#!/usr/bin/env sh
set -eu

# Ensure required vars are present (nice errors if missing)
: "${TURN_DOMAIN:?TURN_DOMAIN is required}"
: "${TURN_LISTEN_PORT:?TURN_LISTEN_PORT is required}"
: "${TURN_TLS_PORT:?TURN_TLS_PORT is required}"
: "${TURN_USERNAME:?TURN_USERNAME is required}"
: "${TURN_PASSWORD:?TURN_PASSWORD is required}"

# Render from template -> final config
envsubst '${TURN_DOMAIN} ${TURN_LISTEN_PORT} ${TURN_TLS_PORT} ${TURN_USERNAME} ${TURN_PASSWORD}' \
  < /etc/pairdrop/rtc_config.template.json \
  > /etc/pairdrop/rtc_config.json

# show what we wrote (without secrets)
sed 's/"credential": *".*"/"credential": "***"/' /etc/pairdrop/rtc_config.json >&2

exec "$@"

