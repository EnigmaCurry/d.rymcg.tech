#!/usr/bin/env bash
set -euox pipefail

echo

DOMAIN="$(${BIN}/wizard ask "Enter the domain name (Subject) of the certificate to create (may be wildcard):" '*.example.com')"
SANS="$(${BIN}/wizard ask --allow-blank "Enter the comma separated list of SANS (alternate domain names) (or leave blank)")"
${BIN}/confirm yes "Do you want to create the certificate for ${DOMAIN} (${SANS})" "?"

# Build -d args
DOMAINS_ARGS="-d ${DOMAIN}"
if [[ -n "${SANS// }" ]]; then
  IFS=',' read -r -a _sans <<< "$SANS"
  for san in "${_sans[@]}"; do
    # trim leading/trailing whitespace
    san="${san#"${san%%[![:space:]]*}"}"
    san="${san%"${san##*[![:space:]]}"}"
    [[ -z "$san" ]] && continue
    DOMAINS_ARGS+=" -d ${san}"
  done
fi

# Pull envs up front so we only expand them once here
ACMEDNS_BASE_URL="$(${BIN}/dotenv -f "${ENV_FILE}" get TRAEFIK_ACME_SH_ACME_DNS_BASE_URL)"
CERT_PERIOD_HOURS="$(${BIN}/dotenv -f "${ENV_FILE}" get TRAEFIK_ACME_SH_CERT_PERIOD_HOURS)"
ACME_CA="$(${BIN}/dotenv -f "${ENV_FILE}" get TRAEFIK_ACME_SH_ACME_CA)"
ACME_DIR="$(${BIN}/dotenv -f "${ENV_FILE}" get TRAEFIK_ACME_SH_ACME_DIRECTORY)"

# Run acme.sh in the cron container.
# Use 'set -f' (noglob) to prevent wildcard domains from being expanded by the shell.
make --no-print-directory docker-compose-shell \
  SERVICE=acme-sh \
  COMMAND="set -f; export ACMEDNS_BASE_URL=${ACMEDNS_BASE_URL} && \
acme.sh --issue ${DOMAINS_ARGS} \
  --dns dns_acmedns \
  --valid-to '+${CERT_PERIOD_HOURS}h' \
  --server https://${ACME_CA}${ACME_DIR} \
  --ca-bundle /acme.sh/root_ca.pem && \
openssl x509 \
  -in "/acme.sh/${DOMAIN}_ecc/${DOMAIN}.cer" \
  -noout \
  -dates \
  -issuer \
  -subject \
  -ext subjectAltName"

make --no-print-directory docker-compose-shell \
  SERVICE=acme-sh \
  COMMAND="set -f; export ACMEDNS_BASE_URL=${ACMEDNS_BASE_URL} && \
mkdir -p /certs/${DOMAIN}/ && \
acme.sh --install-cert ${DOMAINS_ARGS} \
  --key-file       /certs/${DOMAIN}/${DOMAIN}.key \
  --fullchain-file /certs/${DOMAIN}/fullchain.cer \
  --cert-file      /certs/${DOMAIN}/cert.cer \
  --ca-file        /certs/${DOMAIN}/ca.cer \
  --reloadcmd      'touch /traefik/config/dynamic/acme-sh-certs.yml'"
