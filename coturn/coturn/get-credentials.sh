#!/bin/bash
set -eu

USERID=test

# Configuration
: "${STATIC_AUTH_SECRET:?Need to set STATIC_AUTH_SECRET}"
: "${HOST:?Need to set HOST}"
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


human_duration() {
  local s=$1 neg= parts=()
  (( s < 0 )) && { neg="-"; s=$((-s)); }
  local d=$(( s/86400 )); s=$(( s%86400 ))
  local h=$(( s/3600 ));  s=$(( s%3600 ))
  local m=$(( s/60 ));    s=$(( s%60 ))
  (( d )) && parts+=("$d day$([[ $d != 1 ]] && echo s)")
  (( h )) && parts+=("$h hour$([[ $h != 1 ]] && echo s)")
  (( m )) && parts+=("$m minute$([[ $m != 1 ]] && echo s)")
  (( s )) && parts+=("$s second$([[ $s != 1 ]] && echo s)")
  [[ ${#parts[@]} -eq 0 ]] && parts=("0 seconds")
  printf "%s%s" "$neg" "$(IFS=", "; echo "${parts[*]}")"
}


# Output (split labels and values cleanly)
echo
echo "TURN URIs:"
echo
echo "turns:${HOST}:443?transport=tcp"
echo "turn:${HOST}:3478?transport=udp"
echo
echo "Username:"
echo "$USERNAME"
echo
echo "Password:"
echo "$PASSWORD"
echo
echo "Expires at:"
echo "$EXPIRES_AT (in $(human_duration "$TTL_SECONDS"))"
echo
echo "Test URL:"
echo "https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/"
echo
