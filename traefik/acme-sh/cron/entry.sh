#!/usr/bin/env bash
set -euo pipefail
set -f  # avoid globbing of CN like *.example.com

###############################################################################
# Environment Variables
#
# Required:
#   TRAEFIK_ACME_CERT_DOMAINS          JSON list of certificate requests (each have a CN and zero or more SANs): [[CN, [SAN?, ...]], ...]
#   TRAEFIK_ACME_SH_ACME_DNS_BASE_URL  Base URL for acme-dns (e.g. https://acme-dns.example.net)
#   TRAEFIK_ACME_SH_CERT_PERIOD_HOURS  Validity target in hours (e.g. 48)
#   TRAEFIK_ACME_SH_ACME_CA            Step-CA host (e.g. ca.example.com)
#   TRAEFIK_ACME_SH_ACME_DIRECTORY     Path to ACME directory (e.g. /acme/acme/directory)
#   TRAEFIK_ACME_SH_DNS_RESOLVER       Trusted resolver IP (e.g. 1.1.1.1) used inside container
#   TRAEFIK_UID                        Numeric UID of the Traefik user (for chown)
#   TRAEFIK_GID                        Numeric GID of the Traefik user (for chown)
#
# Optional:
#   TRAEFIK_ACME_SH_TRUST_SYSTEM_STORE           true to merge container CA store with Step-CA roots
#   TRAEFIK_ACME_SH_ACMEDNS_ACCOUNT_JSON         Path to saved acme-dns account JSON (default: /acme.sh/acmedns-account.json)
#   TRAEFIK_ACME_SH_ACMEDNS_USERNAME             acme-dns username (preferred over JSON if set)
#   TRAEFIK_ACME_SH_ACMEDNS_PASSWORD             acme-dns password (preferred over JSON if set)
#   TRAEFIK_ACME_SH_ACMEDNS_SUBDOMAIN            acme-dns subdomain (preferred over JSON if set)
#   TRAEFIK_ACME_SH_ACMEDNS_FULLDOMAIN           (optional) fulldomain for printing/checks when using env creds
#   TRAEFIK_ACME_SH_ACMEDNS_ALLOW_FROM           JSON array or comma-separated list of CIDRs for allowfrom (optional)
#   CERTS_DIR                                    Destination for installed certs (default: /certs)
#   TRAEFIK_TOUCH_FILE                           File to touch on successful renew (default: /traefik/restart_me)
#   ACME_ROOT_CA                                 Path to Step-CA root CA bundle (default: /acme.sh/root_ca.pem)
###############################################################################

# -------- required config --------
: "${TRAEFIK_ACME_CERT_DOMAINS:?env required: JSON list of certs, each [CN, [SAN...]]}"
: "${TRAEFIK_ACME_SH_ACME_DNS_BASE_URL:?env required: base URL for acme-dns (ACMEDNS_BASE_URL)}"
: "${TRAEFIK_ACME_SH_CERT_PERIOD_HOURS:?env required: e.g. 48}"
: "${TRAEFIK_ACME_SH_ACME_CA:?env required: e.g. ca.example.com}"
: "${TRAEFIK_ACME_SH_ACME_DIRECTORY:?env required: e.g. /acme/acme/directory}"
: "${TRAEFIK_ACME_SH_DNS_RESOLVER:?env required: trusted DNS server e.g. 1.1.1.1}"
: "${TRAEFIK_UID:?env required: Traefik user UID}"
: "${TRAEFIK_GID:?env required: Traefik user GID}"

# -------- optional config --------
TRUST_SYSTEM="${TRAEFIK_ACME_SH_TRUST_SYSTEM_STORE:-}"   # must be exactly "true" to enable
ACMEDNS_ACCOUNT_JSON="${TRAEFIK_ACME_SH_ACMEDNS_ACCOUNT_JSON:-/acme.sh/acmedns-account.json}"

# DO NOT export these yet; we may hydrate them from JSON if empty:
ACMEDNS_USERNAME="${TRAEFIK_ACME_SH_ACMEDNS_USERNAME:-}"
ACMEDNS_PASSWORD="${TRAEFIK_ACME_SH_ACMEDNS_PASSWORD:-}"
ACMEDNS_SUBDOMAIN="${TRAEFIK_ACME_SH_ACMEDNS_SUBDOMAIN:-}"
ACMEDNS_FULLDOMAIN="${TRAEFIK_ACME_SH_ACMEDNS_FULLDOMAIN:-}"  # nice-to-have for checks/printing

TRAEFIK_ACME_SH_ACMEDNS_ALLOW_FROM="${TRAEFIK_ACME_SH_ACMEDNS_ALLOW_FROM:-}"

CERTS_DIR="${CERTS_DIR:-/certs}"
## You are supposed to be able to get the Traefik file provider to reload from /config/dynamic/acme-sh-certs.yml simply by touching it.
## That mostly works, except that weirdly it does not seem to reload the tls settings without a full traefik restart.
## So, as a workaround, I have rigged the Traefik entrypoint to be restart automatically if it finds the sentinel file at /data/restart_me (aka. /traefik/restart_me in the acme-sh container)
TRAEFIK_TOUCH_FILE="${TRAEFIK_TOUCH_FILE:-/traefik/restart_me}"
ACME_ROOT_CA="${ACME_ROOT_CA:-/acme.sh/root_ca.pem}"

# Common system CA locations (first readable wins)
SYSTEM_CANDIDATES=(/etc/ssl/certs/ca-certificates.crt /etc/pki/tls/certs/ca-bundle.crt /etc/ssl/cert.pem)

log()  { echo "[entrypoint:acme-sh] $*"; }
warn() { echo "[entrypoint:acme-sh] WARNING: $*" >&2; }
fail() { echo "[entrypoint:acme-sh] ERROR: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq not found"
command -v acme.sh >/dev/null 2>&1 || fail "acme.sh not found"
command -v openssl >/dev/null 2>&1 || fail "openssl not found"
command -v curl >/dev/null 2>&1 || fail "curl not found"
command -v dig >/dev/null 2>&1 || warn "dig not found (dns checks will be limited)"

ACME_SERVER="https://${TRAEFIK_ACME_SH_ACME_CA}${TRAEFIK_ACME_SH_ACME_DIRECTORY}"
export ACMEDNS_BASE_URL="${TRAEFIK_ACME_SH_ACME_DNS_BASE_URL}"

# Force resolver for all lookups inside the container (acme.sh uses /etc/resolv.conf)
printf 'nameserver %s\n' "${TRAEFIK_ACME_SH_DNS_RESOLVER}" > /etc/resolv.conf

# ---------- utilities ----------
SYSTEM_CA=""
find_system_ca() {
  for cand in "${SYSTEM_CANDIDATES[@]}"; do
    if [[ -r "$cand" ]]; then SYSTEM_CA="$cand"; return 0; fi
  done
  return 1
}

# Build curl trust args (array) from CABUNDLE or system store later
CURL_TRUST_ARGS=()
CABUNDLE_ARGS=()  # for acme.sh

# ---------- TOFU trust (Step-CA roots, +optionally system store) ----------
tofu_bootstrap_trust() {
  # Reset per-run trust args
  CURL_TRUST_ARGS=()

  # Public CAs (e.g., Let's Encrypt): skip TOFU and use system trust
  case "${TRAEFIK_ACME_SH_ACME_CA}" in
    *api.letsencrypt.org)
      log "Public ACME CA detected (${TRAEFIK_ACME_SH_ACME_CA}); skipping TOFU and using system trust."
      CABUNDLE_ARGS=()   # ensure no leftover custom bundle
      ;;
    *)
      # Attempt TOFU only for non-public (e.g., Step-CA) endpoints
      if [[ ! -f "${ACME_ROOT_CA}" ]]; then
        local ROOTS_URL="https://${TRAEFIK_ACME_SH_ACME_CA}/roots.pem"
        local INTS_URL="https://${TRAEFIK_ACME_SH_ACME_CA}/intermediates.pem"
        log "No ${ACME_ROOT_CA} present; attempting TOFU fetch from ${ROOTS_URL} (+ intermediates)"
        mkdir -p "$(dirname "${ACME_ROOT_CA}")"
        local tmp_roots tmp_ints code_roots code_ints
        tmp_roots="$(mktemp)"; tmp_ints="$(mktemp)"
        code_roots="$(curl -k -sS -w '%{http_code}' -o "${tmp_roots}" "${ROOTS_URL}" || true)"
        if [[ "${code_roots}" == "200" ]] && grep -q "BEGIN CERTIFICATE" "${tmp_roots}"; then
          code_ints="$(curl -k -sS -w '%{http_code}' -o "${tmp_ints}" "${INTS_URL}" || true)"
          if [[ "${code_ints}" == "200" ]] && grep -q "BEGIN CERTIFICATE" "${tmp_ints}"; then
            cat "${tmp_roots}" "${tmp_ints}" > "${ACME_ROOT_CA}"
            log "Wrote root+intermediate bundle to ${ACME_ROOT_CA}"
          else
            cp "${tmp_roots}" "${ACME_ROOT_CA}"
            log "Wrote root-only bundle to ${ACME_ROOT_CA}"
          fi
          awk 'BEGIN{c=0}/BEGIN CERTIFICATE/{c++} {print > ("/tmp/step-ca-" c ".pem")}' "${ACME_ROOT_CA}" || true
          for f in /tmp/step-ca-*.pem; do
            [[ -f "$f" ]] || continue
            openssl x509 -in "$f" -noout -fingerprint -sha256 -subject | sed 's/^/  /'
            rm -f "$f"
          done
          CABUNDLE_ARGS=(--ca-bundle "${ACME_ROOT_CA}")
        else
          log "TOFU fetch not available (status ${code_roots:-<none>} or bad content); will use system trust."
          CABUNDLE_ARGS=()
        fi
        rm -f "${tmp_roots}" "${tmp_ints}" || true
      else
        CABUNDLE_ARGS=(--ca-bundle "${ACME_ROOT_CA}")
      fi
      ;;
  esac

  # Build curl trust and possibly merge with system store
  if [[ "${TRUST_SYSTEM}" == "true" ]]; then
    if find_system_ca; then
      if ((${#CABUNDLE_ARGS[@]})); then
        local COMBINED_BUNDLE="/acme.sh/trust-bundle.pem"
        cat "${ACME_ROOT_CA}" "${SYSTEM_CA}" > "${COMBINED_BUNDLE}"
        CABUNDLE_ARGS=(--ca-bundle "${COMBINED_BUNDLE}")
        CURL_TRUST_ARGS=(--cacert "${COMBINED_BUNDLE}")
        log "Using combined trust bundle (custom + system): ${COMBINED_BUNDLE}"
      else
        CURL_TRUST_ARGS=(--cacert "${SYSTEM_CA}")
        log "Using system trust store only: ${SYSTEM_CA}"
      fi
    else
      warn "System CA store not found/readable; proceeding with ${#CABUNDLE_ARGS[@]}-arg custom bundle (if any)."
      ((${#CABUNDLE_ARGS[@]})) && CURL_TRUST_ARGS=(--cacert "${ACME_ROOT_CA}") || true
    fi
  else
    log "System trust merge disabled (TRAEFIK_ACME_SH_TRUST_SYSTEM_STORE != 'true')."
    ((${#CABUNDLE_ARGS[@]})) && CURL_TRUST_ARGS=(--cacert "${ACME_ROOT_CA}") || true
  fi

  # Preflight ACME directory reachability
  if ! curl -fsS "${CURL_TRUST_ARGS[@]}" "${ACME_SERVER}" >/dev/null; then
    if ((${#CURL_TRUST_ARGS[@]})) && curl -fsS "${ACME_SERVER}" >/dev/null; then
      warn "Preflight failed with provided trust args, but system default worked; continuing with system default for this run."
      CABUNDLE_ARGS=()
      CURL_TRUST_ARGS=()
    else
      fail "Cannot reach ACME directory (${ACME_SERVER}). Check DNS/network or CA trust."
    fi
  fi
}

# ---------- Hydrate acme-dns env from JSON if needed ----------
hydrate_acmedns_env() {
  # If any of the required envs are empty, and JSON is readable, fill from JSON.
  if { [[ -z "${ACMEDNS_USERNAME}" ]] || [[ -z "${ACMEDNS_PASSWORD}" ]] || [[ -z "${ACMEDNS_SUBDOMAIN}" ]]; } \
     && [[ -r "${ACMEDNS_ACCOUNT_JSON}" ]]; then
    local u p s f
    u="$(jq -r '.username // empty'  < "${ACMEDNS_ACCOUNT_JSON}")"
    p="$(jq -r '.password // empty'  < "${ACMEDNS_ACCOUNT_JSON}")"
    s="$(jq -r '.subdomain // empty' < "${ACMEDNS_ACCOUNT_JSON}")"
    f="$(jq -r '.fulldomain // empty' < "${ACMEDNS_ACCOUNT_JSON}")"

    # Only populate missing ones; keep any explicit env overrides
    [[ -z "${ACMEDNS_USERNAME}"  && -n "${u}" ]] && ACMEDNS_USERNAME="${u}"
    [[ -z "${ACMEDNS_PASSWORD}"  && -n "${p}" ]] && ACMEDNS_PASSWORD="${p}"
    [[ -z "${ACMEDNS_SUBDOMAIN}" && -n "${s}" ]] && ACMEDNS_SUBDOMAIN="${s}"
    # fulldomain is optional but useful for checks/printing
    [[ -z "${ACMEDNS_FULLDOMAIN}" && -n "${f}" ]] && ACMEDNS_FULLDOMAIN="${f}"

    log "dns_acmedns: hydrated missing envs from ${ACMEDNS_ACCOUNT_JSON}"
  fi

  # Now export the three required envs for the hook.
  if [[ -n "${ACMEDNS_USERNAME}" && -n "${ACMEDNS_PASSWORD}" && -n "${ACMEDNS_SUBDOMAIN}" ]]; then
    export ACMEDNS_USERNAME ACMEDNS_PASSWORD ACMEDNS_SUBDOMAIN
    return 0
  fi

  fail "ACME-DNS registration not found. Provide env creds (ACMEDNS_USERNAME/PASSWORD/SUBDOMAIN) or mount ${ACMEDNS_ACCOUNT_JSON}."
}

# ---------- Subcommand: register-acmedns ----------
register_acmedns() {
  tofu_bootstrap_trust

  # helper: print exact CNAMEs for all CNs/SANs
  print_cnames() {
    local fd="$1"
    mapfile -t __all_names < <(
      echo "${TRAEFIK_ACME_CERT_DOMAINS}" \
        | jq -r '.[] | [.[0]] + (.[1] // []) | .[]'
    )
    local __tmpfile; __tmpfile="$(mktemp)"
    for __n in "${__all_names[@]}"; do
      local __base
      if [[ "$__n" == \*.* ]]; then
        __base="${__n#*.}"   # strip leading "*."
      else
        __base="$__n"
      fi
      printf "_acme-challenge.%s.\tCNAME\t%s.\n" "$__base" "$fd" >> "$__tmpfile"
    done
    echo
    echo "Create these CNAME records (on your root domain's DNS server) BEFORE traefik install:"
    echo
    sort -u "$__tmpfile" | sed 's/^/  /'
    rm -f "$__tmpfile"
    echo
    if [[ -n "${TRAEFIK_ROOT_DOMAIN:-}" ]] && command -v dig >/dev/null 2>&1; then
      local __d="${TRAEFIK_ROOT_DOMAIN}" __ns=""
      while [[ "$__d" == *.* ]]; do
        __ns="$(dig +short NS "$__d" 2>/dev/null)"
        [[ -n "$__ns" ]] && break
        __d="${__d#*.}"
      done
      if [[ -n "$__ns" ]]; then
        echo "Your authoritative DNS servers for ${__d}:"
        echo "$__ns" | sed 's/^/  /'
        echo
      fi
    fi
  }

  # If already registered, show exact CNAMEs and exit
  if [[ -s "${ACMEDNS_ACCOUNT_JSON}" ]] \
     && jq -e '.fulldomain and .username and .password and .subdomain' >/dev/null 2>&1 < "${ACMEDNS_ACCOUNT_JSON}"
  then
    local fd; fd="$(jq -r '.fulldomain' < "${ACMEDNS_ACCOUNT_JSON}")"
    log "acme-dns account already present at ${ACMEDNS_ACCOUNT_JSON}"
    print_cnames "${fd}"
    echo "When CNAMEs are in place, run the container normally (no subcommand) to issue."
    return 0
  fi

  mkdir -p "$(dirname "${ACMEDNS_ACCOUNT_JSON}")"
  local REG_URL="${ACMEDNS_BASE_URL%/}/register"
  log "Registering acme-dns account: ${REG_URL}"

  # POST {} to /register
  local resp
  resp="$(curl -fsS "${CURL_TRUST_ARGS[@]}" -H 'Content-Type: application/json' -X POST -d '{}' "${REG_URL}")" \
    || fail "acme-dns register failed"

  # Expected keys: username,password,fulldomain,subdomain,allowfrom
  local username password fulldomain subdomain
  username="$(jq -r '.username'  <<<"$resp")"
  password="$(jq -r '.password'  <<<"$resp")"
  fulldomain="$(jq -r '.fulldomain'<<<"$resp")"
  subdomain="$(jq -r '.subdomain' <<<"$resp")"
  [[ -n "$username" && -n "$password" && -n "$fulldomain" && -n "$subdomain" && "$username" != "null" ]] \
    || fail "acme-dns register returned unexpected JSON: $resp"

  # Optional: set allowfrom on server if provided
  if [[ -n "${TRAEFIK_ACME_SH_ACMEDNS_ALLOW_FROM}" ]]; then
    local af_json
    if jq -e . >/dev/null 2>&1 <<<"${TRAEFIK_ACME_SH_ACMEDNS_ALLOW_FROM}"; then
      af_json="${TRAEFIK_ACME_SH_ACMEDNS_ALLOW_FROM}"
    else
      af_json="$(jq -Rc 'split(",") | map(. | gsub("^\\s+|\\s+$";""))' <<<"${TRAEFIK_ACME_SH_ACMEDNS_ALLOW_FROM}")"
    fi
    local UPD_URL="${ACMEDNS_BASE_URL%/}/update"
    log "Setting acme-dns allowfrom="
    curl -fsS "${CURL_TRUST_ARGS[@]}" -H 'Content-Type: application/json' -X POST \
      -d "$(jq -n --arg u "$username" --arg p "$password" --argjson a "${af_json}" '{username:$u,password:$p,allowfrom:$a}')" \
      "${UPD_URL}" >/dev/null || warn "Failed to update allowfrom (continuing)"
  fi

  # Write account file for our own reuse/hydration later
  jq -n --arg u "$username" --arg p "$password" --arg f "$fulldomain" --arg s "$subdomain" \
        --argjson a "$(jq -n '[]')" \
        '{username:$u,password:$p,fulldomain:$f,subdomain:$s,allowfrom:$a}' > "${ACMEDNS_ACCOUNT_JSON}"
  chmod 600 "${ACMEDNS_ACCOUNT_JSON}"

  echo
  echo "acme-dns account saved to: ${ACMEDNS_ACCOUNT_JSON}"
  print_cnames "${fulldomain}"
  echo "When CNAMEs are in place, run the container normally (no subcommand) to issue."
}

# ---------- Issue certs (default path) ----------
issue_all() {
    tofu_bootstrap_trust

    # Prefer env creds; if any missing, hydrate from JSON; then export the triple.
    hydrate_acmedns_env

    log "ACME server: ${ACME_SERVER}"
    log "Target validity: +${TRAEFIK_ACME_SH_CERT_PERIOD_HOURS}h"

    # Only non-LE endpoints support --valid-to (Step-CA does; LE does not)
    VALID_TO_ARGS=()
    case "${TRAEFIK_ACME_SH_ACME_CA}" in
        *api.letsencrypt.org)
            log "Let's Encrypt detected; skipping --valid-to (LE does not support NotBefore/NotAfter)."
            ;;
        *)
            VALID_TO_ARGS=(--valid-to "+${TRAEFIK_ACME_SH_CERT_PERIOD_HOURS}h")
            ;;
    esac

    # (optional) quick CNAME sanity check if we know the fulldomain
    local FD="${ACMEDNS_FULLDOMAIN:-}"
    if [[ -z "$FD" && -r "${ACMEDNS_ACCOUNT_JSON}" ]]; then
        FD="$(jq -r '.fulldomain // empty' < "${ACMEDNS_ACCOUNT_JSON}" 2>/dev/null || true)"
    fi
    if [[ -n "$FD" && -n "$(command -v dig || true)" ]]; then
        mapfile -t ALL_NAMES < <(echo "${TRAEFIK_ACME_CERT_DOMAINS}" | jq -r '.[] | [.[0]] + (.[1] // []) | .[]')
        for n in "${ALL_NAMES[@]}"; do
            local base="$n"
            [[ "$base" == \*.* ]] && base="${base#*.}"  # normalize wildcard
            local got
            got="$(dig +short CNAME "_acme-challenge.${base}" "${TRAEFIK_ACME_SH_DNS_RESOLVER}" +time=2 +tries=1 || true)"
            if [[ "${got%.}" != "${FD%.}" ]]; then
                warn "CNAME missing/mismatch for _acme-challenge.${base}; got='${got:-<none>}' want='${FD}'. Issuance may stall."
            fi
        done
    else
        log "Skipping CNAME sanity check (no fulldomain available)."
    fi

    # -------- Issue all certs --------
    if [[ "$(echo "${TRAEFIK_ACME_CERT_DOMAINS}" | jq 'length')" -eq 0 ]]; then
        log "TRAEFIK_ACME_CERT_DOMAINS is empty; no certificates to request."
        return 0
    fi

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

        # Issue (treat rc=2 as "not due yet"; proceed)
        set +e
        acme.sh --issue \
                "${DOMAINS_ARGS[@]}" \
                --dns dns_acmedns \
                "${VALID_TO_ARGS[@]}" \
                --server "${ACME_SERVER}" \
                "${CABUNDLE_ARGS[@]}"
        rc=$?
        set -e
        if [[ $rc -eq 2 ]]; then
            log "acme.sh reports not due yet (rc=2); continuing to install existing cert paths."
        elif [[ $rc -ne 0 ]]; then
            fail "acme.sh --issue failed with rc=$rc"
        fi

        # Install to deterministic paths (idempotent)
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
}

echo "Setup Finished" > /setup_finished.txt

# ---------- Entrypoint behavior ----------
echo
case "${1-}" in
  register-acmedns)
    register_acmedns
    exit 0
    ;;
  daemon)
    issue_all
    set -x
    exec crond -n -s -m off
    ;;
  *)
    # run issuance then exec the given command
    issue_all
    exec -- "$@"
    ;;
esac
