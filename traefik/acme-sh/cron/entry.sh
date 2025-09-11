#!/usr/bin/env bash
set -euo pipefail
set -f  # avoid globbing of CN like *.example.com

# -------- required config --------
: "${TRAEFIK_ACME_CERT_DOMAINS:?env required: JSON list of certs, each [CN, [SAN...]]}"
: "${TRAEFIK_ACME_SH_ACME_DNS_BASE_URL:?env required: base URL for acme-dns (ACMEDNS_BASE_URL)}"
: "${TRAEFIK_ACME_SH_CERT_PERIOD_HOURS:?env required: e.g. 48}"
: "${TRAEFIK_ACME_SH_ACME_CA:?env required: e.g. ca.rymcg.tech}"
: "${TRAEFIK_ACME_SH_ACME_DIRECTORY:?env required: e.g. /acme/acme/directory}"
: "${TRAEFIK_ACME_SH_DNS_RESOLVER:?env required: trusted DNS server e.g. 1.1.1.1}"
: "${TRAEFIK_UID:?env required: Traefik user UID}"
: "${TRAEFIK_GID:?env required: Traefik user GID}"

# -------- optional paths / toggles --------
CERTS_DIR="${CERTS_DIR:-/certs}"
TRAEFIK_TOUCH_FILE="${TRAEFIK_TOUCH_FILE:-/traefik/config/dynamic/acme-sh-certs.yml}"
ACME_ROOT_CA="${ACME_ROOT_CA:-/acme.sh/root_ca.pem}"
TRUST_SYSTEM="${TRAEFIK_ACME_SH_TRUST_SYSTEM_STORE:-}"   # must be exactly "true" to enable

# Common system CA locations (first readable wins)
SYSTEM_CANDIDATES=(/etc/ssl/certs/ca-certificates.crt /etc/pki/tls/certs/ca-bundle.crt /etc/ssl/cert.pem)

log()  { echo "[entrypoint:acme-sh] $*"; }
warn() { echo "[entrypoint:acme-sh] WARNING: $*" >&2; }
fail() { echo "[entrypoint:acme-sh] ERROR: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq not found"
command -v acme.sh >/dev/null 2>&1 || fail "acme.sh not found"
command -v openssl >/dev/null 2>&1 || fail "openssl not found"
command -v curl >/dev/null 2>&1 || fail "curl not found"

ACME_SERVER="https://${TRAEFIK_ACME_SH_ACME_CA}${TRAEFIK_ACME_SH_ACME_DIRECTORY}"
export ACMEDNS_BASE_URL="${TRAEFIK_ACME_SH_ACME_DNS_BASE_URL}"

cat <<EOF > /etc/resolv.conf
nameserver ${TRAEFIK_ACME_SH_DNS_RESOLVER}
EOF

# -------- TOFU for Step-CA roots --------
CABUNDLE_ARGS=()
if [[ ! -f "${ACME_ROOT_CA}" ]]; then
  ROOTS_URL="https://${TRAEFIK_ACME_SH_ACME_CA}/roots.pem"
  INTS_URL="https://${TRAEFIK_ACME_SH_ACME_CA}/intermediates.pem"
  log "No ${ACME_ROOT_CA} present; TOFU fetch from ${ROOTS_URL} (+ intermediates)"
  mkdir -p "$(dirname "${ACME_ROOT_CA}")"
  tmp_roots="$(mktemp)"; tmp_ints="$(mktemp)"
  if curl -fsS -k "${ROOTS_URL}" -o "${tmp_roots}" && grep -q "BEGIN CERTIFICATE" "${tmp_roots}"; then
    if curl -fsS -k "${INTS_URL}" -o "${tmp_ints}" && grep -q "BEGIN CERTIFICATE" "${tmp_ints}"; then
      cat "${tmp_roots}" "${tmp_ints}" > "${ACME_ROOT_CA}"
      log "Wrote root+intermediate bundle to ${ACME_ROOT_CA}"
    else
      cp "${tmp_roots}" "${ACME_ROOT_CA}"
      log "Wrote root-only bundle to ${ACME_ROOT_CA}"
    fi
    rm -f "${tmp_roots}" "${tmp_ints}"
    # print fingerprints
    awk 'BEGIN{c=0}/BEGIN CERTIFICATE/{c++} {print > ("/tmp/step-ca-" c ".pem")}' "${ACME_ROOT_CA}" || true
    for f in /tmp/step-ca-*.pem; do
      [[ -f "$f" ]] || continue
      openssl x509 -in "$f" -noout -fingerprint -sha256 -subject | sed 's/^/  /'
      rm -f "$f"
    done
    CABUNDLE_ARGS=(--ca-bundle "${ACME_ROOT_CA}")
  else
    warn "Failed to fetch ${ROOTS_URL}; proceeding with system trust (if enabled) or none."
    rm -f "${tmp_roots}" "${tmp_ints}" || true
  fi
else
  CABUNDLE_ARGS=(--ca-bundle "${ACME_ROOT_CA}")
fi

log "ACME server: ${ACME_SERVER}"
log "Target validity: +${TRAEFIK_ACME_SH_CERT_PERIOD_HOURS}h"

# -------- Conditional system store merge --------
CURL_TRUST_ARGS=()
if [[ "${TRUST_SYSTEM}" == "true" ]]; then
  # find readable system CA file
  SYS_CA=""
  for cand in "${SYSTEM_CANDIDATES[@]}"; do
    if [[ -r "$cand" ]]; then SYS_CA="$cand"; break; fi
  done

  if [[ -n "$SYS_CA" ]]; then
    if ((${#CABUNDLE_ARGS[@]})); then
      COMBINED_BUNDLE="/acme.sh/trust-bundle.pem"
      cat "${ACME_ROOT_CA}" "${SYS_CA}" > "${COMBINED_BUNDLE}"
      CABUNDLE_ARGS=(--ca-bundle "${COMBINED_BUNDLE}")
      log "Using combined trust bundle (Step-CA + system): ${COMBINED_BUNDLE}"
      CURL_TRUST_ARGS=(--cacert "${COMBINED_BUNDLE}")
    else
      # No Step-CA bundle → rely purely on system trust
      log "Using system trust store only: ${SYS_CA}"
      CURL_TRUST_ARGS=(--cacert "${SYS_CA}")
      CABUNDLE_ARGS=()  # acme.sh without explicit bundle → system trust
    fi
  else
    warn "System CA store not found/readable; continuing without it."
    # If Step-CA bundle exists, leave CABUNDLE_ARGS as-is; curl will preflight below with none.
  fi
else
  log "System trust store merge disabled (TRAEFIK_ACME_SH_TRUST_SYSTEM_STORE != 'true')."
  if ((${#CABUNDLE_ARGS[@]})); then
    CURL_TRUST_ARGS=(--cacert "${ACME_ROOT_CA}")
  else
    CURL_TRUST_ARGS=()  # no explicit trust args
  fi
fi

# -------- Preflight reachability --------
if ! curl -fsS "${CURL_TRUST_ARGS[@]}" "${ACME_SERVER}" >/dev/null; then
  # Helpful fallback: if we were using a bundle, try system trust silently
  if ((${#CURL_TRUST_ARGS[@]})) && curl -fsS "${ACME_SERVER}" >/dev/null; then
    warn "Preflight failed with provided bundle, but system trust worked; continuing with system trust for this run."
    CABUNDLE_ARGS=()
    CURL_TRUST_ARGS=()
  else
    fail "Cannot reach ACME directory (${ACME_SERVER}). Check DNS/network or CA trust."
  fi
fi

# (Optional) enforce non-interactive acme-dns config:
# if [[ -z "${ACMEDNS_ACCOUNT_JSON:-}" && ( -z "${ACMEDNS_USERNAME:-}" || -z "${ACMEDNS_PASSWORD:-}" || -z "${ACMEDNS_SUBDOMAIN:-}" ) ]]; then
#   fail "dns_acmedns not configured for non-interactive use; set ACMEDNS_ACCOUNT_JSON or ACMEDNS_* envs."
# fi

# -------- Issue all certs --------
if [[ "$(echo "${TRAEFIK_ACME_CERT_DOMAINS}" | jq 'length')" -eq 0 ]]; then
  log "TRAEFIK_ACME_CERT_DOMAINS is empty; no certificates to request."
else
  while IFS= read -r item; do
    CN="$(jq -r '.[0]' <<<"$item")"
    mapfile -t SANS < <(jq -r '.[1] // [] | .[]' <<<"$item")
    [[ -n "$CN" ]] || fail "Encountered a cert entry with empty CN"

    DOMAINS_ARGS=(-d "$CN")
    for san in "${SANS[@]}"; do [[ -n "$san" ]] && DOMAINS_ARGS+=(-d "$san"); done

    log "Requesting certificate:"
    log "  CN:   $CN"
    ((${#SANS[@]})) && log "  SANs: ${SANS[*]}" || log "  SANs: (none)"
    mkdir -p "${CERTS_DIR}/${CN}"

    acme.sh --issue \
      "${DOMAINS_ARGS[@]}" \
      --dns dns_acmedns \
      --valid-to "+${TRAEFIK_ACME_SH_CERT_PERIOD_HOURS}h" \
      --server "${ACME_SERVER}" \
      "${CABUNDLE_ARGS[@]}"

    acme.sh --install-cert \
      "${DOMAINS_ARGS[@]}" \
      --key-file       "${CERTS_DIR}/${CN}/${CN}.key" \
      --fullchain-file "${CERTS_DIR}/${CN}/fullchain.cer" \
      --cert-file      "${CERTS_DIR}/${CN}/cert.cer" \
      --ca-file        "${CERTS_DIR}/${CN}/ca.cer" \
      --reloadcmd      "touch '${TRAEFIK_TOUCH_FILE}'"

    chown -R "${TRAEFIK_UID}:${TRAEFIK_GID}" "${CERTS_DIR}/${CN}"

    if [[ -f "/acme.sh/${CN}_ecc/${CN}.cer" ]]; then
      log "Certificate details for ${CN}:"
      openssl x509 -in "/acme.sh/${CN}_ecc/${CN}.cer" \
        -noout -dates -issuer -subject -ext subjectAltName | sed 's/^/  /'
    fi
    log "Installed files under: ${CERTS_DIR}/${CN}"
  done < <(echo "${TRAEFIK_ACME_CERT_DOMAINS}" | jq -c '.[]')
fi

# -------- run daemon or exec --------
if [[ "${1-}" == "daemon" ]]; then
  set -x
  exec crond -n -s -m off
else
  exec -- "$@"
fi
