#!/usr/bin/env bash
set -euo pipefail

# Required inputs (no defaults)
: "${SUBDOMAIN:?SUBDOMAIN is required (e.g. acme-dns.example.com)}"
: "${NSNAME:?NSNAME is required (e.g. auth.acme-dns.example.com)}"
: "${PUBLIC_IP_ADDRESS:?PUBLIC_IP_ADDRESS is required (IPv4 or IPv6)}"
: "${NSADMIN:?NSADMIN is required (SOA RNAME like hostmaster.example.com)}"
: "${DISABLE_REGISTRATION}:?DISABLE_REGISTRATION is required (true/false)"
: "${API_PORT}:?API_PORT is required"

NSADMIN=$(echo $NSADMIN | sed -s 's/@/./')

# Optional
RECORDS="${RECORDS:-}"

# Output file
OUTFILE="${OUTFILE:-/config/config.cfg}"

fqdn_dot() {
  # Ensure trailing dot on an FQDN
  local n="$1"
  [[ "$n" == *"." ]] && echo "$n" || echo "${n}."
}

# Normalize FQDNs
SUBDOMAIN_FQDN="$(fqdn_dot "$SUBDOMAIN")"
NSNAME_FQDN="$(fqdn_dot "$NSNAME")"

# Decide A vs AAAA from IP
if [[ "$PUBLIC_IP_ADDRESS" == *:* ]]; then
  ADDR_TYPE="AAAA"
else
  ADDR_TYPE="A"
fi

# Build records array starting with the two defaults
# 1) nameserver host -> A/AAAA IP
# 2) delegated zone -> NS nsname
mapfile -t RECORD_LIST < <(printf "%s\n" \
  "${NSNAME_FQDN} ${ADDR_TYPE} ${PUBLIC_IP_ADDRESS}" \
  "${SUBDOMAIN_FQDN} NS ${NSNAME_FQDN}")

# Append extras from RECORDS (comma-separated tuples)
if [[ -n "$RECORDS" ]]; then
  IFS=',' read -ra REC_ARR <<< "$RECORDS"
  for rec in "${REC_ARR[@]}"; do
    rec_trimmed="$(echo "$rec" | xargs)"
    [[ -n "$rec_trimmed" ]] && RECORD_LIST+=("$rec_trimmed")
  done
fi

# Write config
cat > "$OUTFILE" <<EOF
[general]
listen = "0.0.0.0:53"
protocol = "both"
domain = "${SUBDOMAIN}"
nsname = "${NSNAME}"
nsadmin = "${NSADMIN}"
records = [
EOF

# Emit TOML array items with proper commas
for i in "${!RECORD_LIST[@]}"; do
  rec="${RECORD_LIST[$i]}"
  if (( i < ${#RECORD_LIST[@]} - 1 )); then
    printf '  "%s",\n' "$rec" >> "$OUTFILE"
  else
    printf '  "%s"\n' "$rec" >> "$OUTFILE"
  fi
done

cat >> "$OUTFILE" <<EOF
]

[database]
engine = "sqlite3"
connection = "/var/lib/acme-dns/acme-dns.db"

[api]
ip = "0.0.0.0"
disable_registration = ${DISABLE_REGISTRATION}
port = "${API_PORT}"
tls = "letsencrypt"
corsorigins = [
    "*"
]
use_header = true
header_name = "X-Forwarded-For"

[logconfig]
# logging level: "error", "warning", "info" or "debug"
loglevel = "debug"
# possible values: stdout, TODO file & integrations
logtype = "stdout"
# file path for logfile TODO
# logfile = "./acme-dns.log"
# format, either "json" or "text"
logformat = "text"
EOF

echo "Generated $OUTFILE"
