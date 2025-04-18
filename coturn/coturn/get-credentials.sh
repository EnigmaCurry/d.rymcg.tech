#!/bin/sh
set -eu

USERID=test

# Configuration
: "${STATIC_AUTH_SECRET:?Need to set STATIC_AUTH_SECRET}"
: "${REALM:?Need to set REALM}"
: "${USERID:?Need to set USERID}"   # <-- User ID to embed
TTL_SECONDS="${TTL_SECONDS:-300}"   # Default 5 minutes TTL

# Current time
NOW=$(date +%s)

# Username = timestamp:userid
USERNAME="$(($NOW + $TTL_SECONDS)):$USERID"

# Compute password
PASSWORD=$(echo -n "$USERNAME" | openssl dgst -binary -sha1 -hmac "$STATIC_AUTH_SECRET" | base64)

# Expiration time (human readable)
EXPIRES_AT=$(date -d "@$(echo $USERNAME | cut -d: -f1)" "+%Y-%m-%d %H:%M:%S %Z")

# Output (split labels and values cleanly)
echo
echo "TURN URI:"
echo "turns:${REALM}:3478"
echo
echo "Username:"
echo "$USERNAME"
echo
echo "Password:"
echo "$PASSWORD"
echo
echo "Expires at:"
echo "$EXPIRES_AT (in $(($TTL_SECONDS/60)) minutes)"
echo
echo "Test URL:"
echo "https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/"
echo
