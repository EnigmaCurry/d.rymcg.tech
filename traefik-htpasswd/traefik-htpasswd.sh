#!/bin/bash
read -p "Enter the username for HTTP Basic Authentication: " USERNAME
PLAIN_PASSWORD=$(openssl rand -base64 30 | head -c 20)
HASH_PASSWORD=$(echo $PLAIN_PASSWORD | htpasswd -inB ${USERNAME})
echo "Plain text password (save this): ${PLAIN_PASSWORD}"
echo "Hashed user/password (copy this to .env): ${HASH_PASSWORD}"
URL_ENCODED=https://${USERNAME}:$(python3 -c "from urllib.parse import quote; print(quote('''${PLAIN_PASSWORD=}'''))")@example.com/...
echo "Url encoded: ${URL_ENCODED}"
