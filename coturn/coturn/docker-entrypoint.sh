#!/bin/bash
set -e

# Original behavior: if the first arg starts with '-', prepend "turnserver"
if [ "${1:0:1}" == '-' ]; then
  set -- turnserver "$@"
fi

# Wait for TLS cert and key
echo "Waiting for TLS cert and key to be available..."

while [ ! -f "$CERT_PATH" ]; do
    echo "Waiting for cert file at $CERT_PATH..."
    sleep 1
done

while [ ! -f "$KEY_PATH" ]; do
    echo "Waiting for key file at $KEY_PATH..."
    sleep 1
done

echo "Certificates found, copying..."

# Copy certs to internal directory and fix ownership
mkdir -p /var/lib/coturn/certs
cp "$CERT_PATH" /var/lib/coturn/certs/fullchain.pem
cp "$KEY_PATH" /var/lib/coturn/certs/privkey.pem

chown nobody:nogroup /var/lib/coturn/certs/fullchain.pem
chown nobody:nogroup /var/lib/coturn/certs/privkey.pem
chmod 600 /var/lib/coturn/certs/*

# Update paths to point to copied certs
export CERT_PATH=/var/lib/coturn/certs/fullchain.pem
export KEY_PATH=/var/lib/coturn/certs/privkey.pem

# Drop privileges manually
echo "Dropping privileges to nobody:nogroup"
exec gosu nobody:nogroup "$@"
