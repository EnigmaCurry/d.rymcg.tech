#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR=/home/user/git/vendor/enigmacurry/d.rymcg.tech
BIN="${ROOT_DIR}/_scripts"

## Step 0: Set up PATH so the d.rymcg.tech CLI works
export PATH="${ROOT_DIR}/_scripts/user:${PATH}"

## Step 1: Validate DOCKER_CONTEXT (SSH_HOST validation deferred to Step 5)
if [[ -z "${DOCKER_CONTEXT}" ]]; then
    echo "ERROR: DOCKER_CONTEXT is required" >&2
    exit 1
fi

## Step 2: Generate SSH key
KEY_DIR=/run/secrets/ssh
mkdir -p "${KEY_DIR}" ~/.ssh && chmod 700 "${KEY_DIR}" ~/.ssh
if [[ ! -f "${KEY_DIR}/id_ed25519" ]]; then
    ssh-keygen -t ed25519 -N "" -f "${KEY_DIR}/id_ed25519" -q
fi

## Step 3: OpenBao integration (only runs if BAO_ADDR is set)
if [[ -n "${BAO_ADDR:-}" ]]; then
    echo "## OpenBao: authenticating with ${BAO_ADDR}" >&2

    ## Step 3a: Resolve BAO TLS vars (auto-detect base64/PEM/file paths → temp files)
    resolve_tls_var() {
        local var_name="$1"
        local var_value="${!var_name:-}"
        [[ -z "${var_value}" ]] && return 0
        # File path — use as-is
        if [[ -f "${var_value}" ]]; then
            return 0
        fi
        local tmp_file
        tmp_file=$(mktemp "${KEY_DIR}/${var_name}.XXXXXX")
        # Inline PEM content
        if [[ "${var_value}" == *"-----BEGIN"* ]]; then
            echo "${var_value}" > "${tmp_file}"
            export "${var_name}=${tmp_file}"
            return 0
        fi
        # Base64-encoded content (single line, >60 chars, valid base64 chars)
        if [[ $(echo "${var_value}" | wc -l) -eq 1 ]] && \
           [[ ${#var_value} -gt 60 ]] && \
           echo "${var_value}" | grep -qE '^[A-Za-z0-9+/=]+$'; then
            echo "${var_value}" | base64 -d > "${tmp_file}"
            export "${var_name}=${tmp_file}"
            return 0
        fi
        # Not a recognized format — leave as-is (may be a URL or other ref)
        rm -f "${tmp_file}"
    }

    resolve_tls_var BAO_CACERT
    resolve_tls_var BAO_CLIENT_CERT
    resolve_tls_var BAO_CLIENT_KEY

    # Build curl TLS flags
    BAO_CURL_FLAGS=()
    [[ -n "${BAO_CACERT:-}" ]]      && BAO_CURL_FLAGS+=(--cacert "${BAO_CACERT}")
    [[ -n "${BAO_CLIENT_CERT:-}" ]] && BAO_CURL_FLAGS+=(--cert "${BAO_CLIENT_CERT}")
    [[ -n "${BAO_CLIENT_KEY:-}" ]]  && BAO_CURL_FLAGS+=(--key "${BAO_CLIENT_KEY}")

    BAO_AUTH_PATH="${BAO_AUTH_PATH:-auth/approle}"
    BAO_SSH_MOUNT="${BAO_SSH_MOUNT:-ssh-client-signer}"
    BAO_SSH_ROLE="${BAO_SSH_ROLE:-woodpecker-short-lived}"
    BAO_KV_MOUNT="${BAO_KV_MOUNT:-secret}"

    # Validate required vars
    if [[ -z "${BAO_ROLE_ID:-}" ]]; then
        echo "ERROR: BAO_ROLE_ID is required when BAO_ADDR is set" >&2
        exit 1
    fi
    if [[ -z "${BAO_SECRET_ID:-}" ]]; then
        echo "ERROR: BAO_SECRET_ID is required when BAO_ADDR is set" >&2
        exit 1
    fi
    if [[ -z "${BAO_AGE_KEY_PATH:-}" ]]; then
        echo "ERROR: BAO_AGE_KEY_PATH is required when BAO_ADDR is set (e.g., sops/myserver-production)" >&2
        exit 1
    fi

    ## Step 3b: AppRole authentication via curl → get BAO_TOKEN
    echo "## OpenBao: logging in via AppRole" >&2
    BAO_NAMESPACE_HEADER=()
    [[ -n "${BAO_NAMESPACE:-}" ]] && BAO_NAMESPACE_HEADER=(-H "X-Vault-Namespace: ${BAO_NAMESPACE}")
    LOGIN_RESPONSE=$(curl -sf "${BAO_CURL_FLAGS[@]}" "${BAO_NAMESPACE_HEADER[@]}" \
        --request POST \
        --data "{\"role_id\":\"${BAO_ROLE_ID}\",\"secret_id\":\"${BAO_SECRET_ID}\"}" \
        "${BAO_ADDR}/v1/${BAO_AUTH_PATH}/login")
    BAO_TOKEN=$(echo "${LOGIN_RESPONSE}" | jq -r '.auth.client_token')
    if [[ -z "${BAO_TOKEN}" || "${BAO_TOKEN}" == "null" ]]; then
        echo "ERROR: OpenBao AppRole login failed" >&2
        echo "${LOGIN_RESPONSE}" >&2
        exit 1
    fi
    echo "## OpenBao: authenticated successfully" >&2

    ## Step 3c: Retrieve AGE key from KV store → write to temp file, set SOPS_AGE_KEY_FILE
    echo "## OpenBao: retrieving AGE key from ${BAO_KV_MOUNT}/data/${BAO_AGE_KEY_PATH}" >&2
    AGE_RESPONSE=$(curl -sf "${BAO_CURL_FLAGS[@]}" "${BAO_NAMESPACE_HEADER[@]}" \
        -H "X-Vault-Token: ${BAO_TOKEN}" \
        "${BAO_ADDR}/v1/${BAO_KV_MOUNT}/data/${BAO_AGE_KEY_PATH}")
    AGE_KEY=$(echo "${AGE_RESPONSE}" | jq -r '.data.data.key')
    if [[ -z "${AGE_KEY}" || "${AGE_KEY}" == "null" ]]; then
        echo "ERROR: Failed to retrieve AGE key from OpenBao" >&2
        echo "${AGE_RESPONSE}" >&2
        exit 1
    fi
    AGE_KEY_FILE=$(mktemp "${KEY_DIR}/age-key.XXXXXX")
    echo "${AGE_KEY}" > "${AGE_KEY_FILE}"
    chmod 600 "${AGE_KEY_FILE}"
    export SOPS_AGE_KEY_FILE="${AGE_KEY_FILE}"
    echo "## OpenBao: AGE key retrieved" >&2

    ## Step 3d: Sign SSH public key via SSH secrets engine → write certificate
    echo "## OpenBao: signing SSH public key via ${BAO_SSH_MOUNT}/sign/${BAO_SSH_ROLE}" >&2
    SSH_PUBLIC_KEY=$(cat "${KEY_DIR}/id_ed25519.pub")
    SIGN_RESPONSE=$(curl -sf "${BAO_CURL_FLAGS[@]}" "${BAO_NAMESPACE_HEADER[@]}" \
        -H "X-Vault-Token: ${BAO_TOKEN}" \
        --request POST \
        --data "{\"public_key\":\"${SSH_PUBLIC_KEY}\"}" \
        "${BAO_ADDR}/v1/${BAO_SSH_MOUNT}/sign/${BAO_SSH_ROLE}")
    SIGNED_KEY=$(echo "${SIGN_RESPONSE}" | jq -r '.data.signed_key')
    if [[ -z "${SIGNED_KEY}" || "${SIGNED_KEY}" == "null" ]]; then
        echo "ERROR: SSH certificate signing failed" >&2
        echo "${SIGN_RESPONSE}" >&2
        exit 1
    fi
    echo "${SIGNED_KEY}" > "${KEY_DIR}/id_ed25519-cert.pub"
    chmod 600 "${KEY_DIR}/id_ed25519-cert.pub"
    echo "## OpenBao: SSH certificate obtained" >&2
fi

## Step 4: SOPS config file loading (only runs if SOPS_CONFIG_FILE is set)
if [[ -n "${SOPS_CONFIG_FILE:-}" ]]; then
    echo "## Loading SOPS config from ${SOPS_CONFIG_FILE}" >&2
    if [[ ! -f "${SOPS_CONFIG_FILE}" ]]; then
        echo "ERROR: SOPS_CONFIG_FILE not found: ${SOPS_CONFIG_FILE}" >&2
        exit 1
    fi
    SOPS_DECRYPTED=$(sops decrypt --input-type dotenv --output-type dotenv \
        --filename-override export.env "${SOPS_CONFIG_FILE}")

    # Delete AGE key temp file after decryption (no longer needed)
    if [[ -n "${AGE_KEY_FILE:-}" && -f "${AGE_KEY_FILE}" ]]; then
        rm -f "${AGE_KEY_FILE}"
        unset SOPS_AGE_KEY_FILE
    fi

    # Parse each KEY=VALUE; skip BAO_* vars; export only if not already set
    while IFS= read -r line; do
        [[ -z "${line}" || "${line}" == "#"* ]] && continue
        key="${line%%=*}"
        val="${line#*=}"
        # Never load BAO_* vars from SOPS (must come from container env)
        [[ "${key}" == BAO_* ]] && continue
        # Only set if not already defined in container env (container env wins)
        if [[ -z "${!key+set}" ]]; then
            export "${key}=${val}"
        fi
    done <<< "${SOPS_DECRYPTED}"
    echo "## SOPS config loaded" >&2
fi

## Step 5: Validate SSH vars + write SSH config (SSH_HOST may now come from SOPS)
if [[ -z "${SSH_HOST:-}" ]]; then
    echo "ERROR: SSH_HOST is required (set via container env or SOPS config)" >&2
    exit 1
fi
SSH_USER="${SSH_USER:-root}"
SSH_PORT="${SSH_PORT:-22}"

if [[ "${SSH_KEY_SCAN:-}" != "false" ]]; then
    if ! ssh-keyscan -p "${SSH_PORT}" "${SSH_HOST}" >> "${KEY_DIR}/known_hosts" 2>/dev/null; then
        echo "ERROR: ssh-keyscan failed for ${SSH_HOST}:${SSH_PORT} (set SSH_KEY_SCAN=false to skip)" >&2
        exit 1
    fi
fi
{
    echo "Host ${DOCKER_CONTEXT}"
    echo "    HostName ${SSH_HOST}"
    echo "    User ${SSH_USER}"
    echo "    Port ${SSH_PORT}"
    echo "    IdentityFile ${KEY_DIR}/id_ed25519"
    echo "    UserKnownHostsFile ${KEY_DIR}/known_hosts"
    # Include CertificateFile only if an SSH certificate was obtained
    if [[ -f "${KEY_DIR}/id_ed25519-cert.pub" ]]; then
        echo "    CertificateFile ${KEY_DIR}/id_ed25519-cert.pub"
    fi
} > ~/.ssh/config
chmod 600 ~/.ssh/config

## Step 6: Create and activate Docker context
docker context create "${DOCKER_CONTEXT}" \
    --docker "host=ssh://${SSH_USER}@${SSH_HOST}:${SSH_PORT}" &>/dev/null || true
docker context use "${DOCKER_CONTEXT}" &>/dev/null

## Step 7: Create root .env and distribute env vars via restore-env
cd "${ROOT_DIR}"
cp -n .env-dist ".env_${DOCKER_CONTEXT}"
env | d.rymcg.tech restore-env

## Step 8: Ensure explicitly requested projects have env files
if [[ -n "${_PROJECTS:-}" ]]; then
    IFS=, read -ra _requested_projects <<< "${_PROJECTS}"
    for project_name in "${_requested_projects[@]}"; do
        env_file="${project_name}/.env_${DOCKER_CONTEXT}_default"
        if [[ ! -f "${env_file}" ]]; then
            cp "${project_name}/.env-dist" "${env_file}"
        fi
    done
fi

## Step 9: Exec the command
exec "$@"
