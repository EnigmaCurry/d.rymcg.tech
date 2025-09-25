#!/bin/bash
set -eu

# Configuration
: "${STATIC_AUTH_SECRET:?Need to set STATIC_AUTH_SECRET}"
: "${HOST:?Need to set HOST}"
: "${REALM:?Need to set REALM}"
: "${USER_ID:?Need to set USER_ID}"   # <-- User ID to embed
TTL_SECONDS="${TTL_SECONDS:-14400}"   # Default 4 hour TTL

# Current time
NOW=$(date +%s)

# Username = timestamp:userid
USERNAME="$(($NOW + $TTL_SECONDS)):$USER_ID"

# Compute password
PASSWORD=$(echo -n "$USERNAME" | openssl dgst -binary -sha1 -hmac "$STATIC_AUTH_SECRET" | base64)

# Expiration time (human readable)
EXPIRES_AT=$(date -d "@$(echo $USERNAME | cut -d: -f1)" "+%Y-%m-%d %H:%M:%S %Z")

# Verbose: "1 year, 2 months, 3 days, 4 hours, 5 minutes, 6 seconds"
human_duration() {
  local s=$1 neg= parts=()
  (( s < 0 )) && { neg="-"; s=$((-s)); }

  local SEC_MIN=60
  local SEC_HOUR=$((60*SEC_MIN))
  local SEC_DAY=$((24*SEC_HOUR))
  local SEC_MONTH=$((30*SEC_DAY))   # ≈ month
  local SEC_YEAR=$((365*SEC_DAY))   # ≈ year

  local y=$(( s / SEC_YEAR ));  s=$(( s % SEC_YEAR ))
  local mo=$(( s / SEC_MONTH )); s=$(( s % SEC_MONTH ))
  local d=$(( s / SEC_DAY ));   s=$(( s % SEC_DAY ))
  local h=$(( s / SEC_HOUR ));  s=$(( s % SEC_HOUR ))
  local m=$(( s / SEC_MIN ));   s=$(( s % SEC_MIN ))

  (( y  )) && parts+=("$y year$([[ $y  != 1 ]] && echo s)")
  (( mo )) && parts+=("$mo month$([[ $mo != 1 ]] && echo s)")
  (( d  )) && parts+=("$d day$([[ $d  != 1 ]] && echo s)")
  (( h  )) && parts+=("$h hour$([[ $h  != 1 ]] && echo s)")
  (( m  )) && parts+=("$m minute$([[ $m != 1 ]] && echo s)")
  (( s  )) && parts+=("$s second$([[ $s  != 1 ]] && echo s)")

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
