#!/bin/sh
set -e

timeout=300  # 5 minutes in seconds
interval=5   # Check every 5 seconds

while [ $timeout -gt 0 ]; do
    if [ -f /mosquitto/certs/fullchain.pem ] && \
       [ -f /mosquitto/certs/cert.pem ] && \
       [ -f /mosquitto/certs/privkey.pem ]; then
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

# Remove the restart-trigger file if it exists
if [ -f /mosquitto/certs/restart-trigger ]; then
    rm /mosquitto/certs/restart-trigger
    echo "## Removed restart-trigger file."
fi

# Start Mosquitto
exec mosquitto -c /mosquitto/config/mosquitto.conf
