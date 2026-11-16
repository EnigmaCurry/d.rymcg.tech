#!/bin/sh
set -e

timeout=300  # 5 minutes in seconds
interval=5   # Check every 5 seconds

if [[ -z "${MOSQUITTO_TRAEFIK_HOST}" ]]; then
    echo "MOSQUITTO_TRAEFIK_HOST is empty".
    exit 1
fi

while [ $timeout -gt 0 ]; do
    if [ -f /mosquitto/certs/${MOSQUITTO_TRAEFIK_HOST}.crt ] && \
       [ -f /mosquitto/certs/${MOSQUITTO_TRAEFIK_HOST}.key ] && \
       [ -f /mosquitto/certs/root_ca.crt ]; then
        chown -R mosquitto:mosquitto /mosquitto/certs/*
        echo "## Found full TLS certificate chain."
        break
    fi
    if [ $(( (timeout / interval) % 5 )) -eq 0 ]; then
        echo "## Waiting for TLS certificate creation before startup ..."
    fi
    sleep $interval
    timeout=$((timeout - interval))
done

if [ $timeout -le 0 ]; then
    echo "## Timeout: Not all required files exist after 5 minutes."
    exit 1
fi

# Build the CA bundle used to verify client certificates: the
# intermediate(s) from the server certificate chain plus the root.
# Some clients (e.g. OwnTracks on iOS) send only their leaf
# certificate, not the intermediate, so the root alone can't verify them.
CERT=/mosquitto/certs/${MOSQUITTO_TRAEFIK_HOST}.crt
CA_BUNDLE=/mosquitto/certs/ca_bundle.crt
awk '/-----BEGIN CERTIFICATE-----/ {n++} n > 1' "${CERT}" > "${CA_BUNDLE}.tmp"
cat /mosquitto/certs/root_ca.crt >> "${CA_BUNDLE}.tmp"
mv "${CA_BUNDLE}.tmp" "${CA_BUNDLE}"
chown mosquitto:mosquitto "${CA_BUNDLE}"
echo "## Wrote CA bundle ($(grep -c 'BEGIN CERTIFICATE' "${CA_BUNDLE}") certificates): ${CA_BUNDLE}"

# Remove the restart-trigger file if it exists
if [ -f /mosquitto/certs/restart-trigger ]; then
    rm /mosquitto/certs/restart-trigger
    echo "## Removed restart-trigger file."
fi

# Start Mosquitto
exec mosquitto -c /mosquitto/config/mosquitto.conf
