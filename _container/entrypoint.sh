#!/usr/bin/env bash
## d.rymcg.tech workstation Docker entrypoint
## Handles SSH keys, OpenBao auth, SOPS decryption, and Docker context setup.
set -eo pipefail

ROOT_DIR=/home/user/git/vendor/enigmacurry/d.rymcg.tech
BIN="${ROOT_DIR}/_scripts"

## Step 0: Set up PATH so the d.rymcg.tech CLI works
export PATH="${ROOT_DIR}/_scripts/user:${PATH}"

## Short-circuit: "drt" with no args outputs itself (for alias extraction);
## "drt <args>" execs directly (no entrypoint setup needed)
if [[ "${1:-}" == "drt" ]]; then
    if [[ $# -eq 1 ]]; then
        exec drt --extract
    fi
    exec "$@"
fi

## Preflight: detect unconfigured container
if [[ -z "${SSH_HOST:-}" && -z "${SOPS_CONFIG_FILE:-}" && -z "${BAO_ADDR:-}" && -z "${DOCKER_CONTEXT:-}" ]]; then
    echo "##    d-rymcg-tech container is not configured." >&2
    echo "##" >&2
    echo "##    See:" >&2
    echo "##      https://github.com/EnigmaCurry/d.rymcg.tech/blob/master/WORKSTATION_CONTAINER.md" >&2
    echo "##" >&2
    echo "##    == CI / headless usage ==" >&2
    echo "##    Set environment variables: SSH_HOST, SSH_USER, SSH_PORT" >&2
    echo "##    Or for OpenBao: BAO_ADDR, BAO_ROLE_ID, BAO_SECRET_ID, BAO_AGE_KEY_PATH" >&2
    echo "##    Use plain env vars, SOPS_CONFIG_FILE, or both (env vars override SOPS)." >&2
    echo "##" >&2
    echo "##    == Interactive usage (drt) ==" >&2
    # Print the setup instructions from the drt script's trailing comment block
    awk -v img="${DRT_IMAGE:-localhost/d-rymcg-tech}" '/^###/ { if (in_block) { in_block=0 } else { in_block=1; buf="" }; next } in_block { sub(/^# ?/, ""); gsub(/@@DRT_IMAGE@@/, img); buf = buf "##    " $0 "\n" } END { printf "%s", buf }' /usr/local/bin/drt >&2
    echo "##" >&2
    echo "##    == Debug usage (unconfirmed SSH host foo) ==" >&2
    echo "##    podman run --rm -it -e SSH_HOST=foo -e SSH_KEY_SCAN=false ${DRT_IMAGE:-localhost/d-rymcg-tech}" >&2
    exit 1
fi

## Helper: resolve a secret value (file path, PEM, or base64) → write to target file
resolve_secret_to_file() {
    local value="$1" target="$2"
    [[ -z "${value}" ]] && return 1
    # File path — copy it
    if [[ -f "${value}" ]]; then
        cp "${value}" "${target}"
    # Inline PEM content
    elif [[ "${value}" == *"-----BEGIN"* ]]; then
        echo "${value}" > "${target}"
    # Base64-encoded content (single line, >60 chars, valid base64 chars)
    elif [[ $(echo "${value}" | wc -l) -eq 1 ]] && \
         [[ ${#value} -gt 60 ]] && \
         echo "${value}" | grep -qE '^[A-Za-z0-9+/=]+$'; then
        echo "${value}" | base64 -d > "${target}"
    # Plain text (e.g. known_hosts content)
    else
        echo "${value}" > "${target}"
    fi
    chmod 600 "${target}"
}

## Step 1: Set up SSH key directory and credentials
echo "## Step 1: Setting up SSH credentials" >&2
KEY_DIR=/run/secrets/ssh
mkdir -p "${KEY_DIR}" 2>/dev/null || KEY_DIR=$(mktemp -d)
mkdir -p ~/.ssh
chmod 700 "${KEY_DIR}" ~/.ssh

# Hydrate SSH_KEY from env (file path, PEM, or base64)
if [[ -n "${SSH_KEY:-}" && ! -f "${KEY_DIR}/id_ed25519" ]]; then
    echo "## SSH: loading key from SSH_KEY env var" >&2
    resolve_secret_to_file "${SSH_KEY}" "${KEY_DIR}/id_ed25519"
fi

# Generate a key if none was provided or mounted
if [[ ! -f "${KEY_DIR}/id_ed25519" ]]; then
    ssh-keygen -t ed25519 -N "" -f "${KEY_DIR}/id_ed25519" -q
fi

## Step 2: OpenBao integration (only runs if BAO_ADDR is set)
echo "## Step 2: OpenBao integration" >&2
if [[ -n "${BAO_ADDR:-}" ]]; then
    echo "## OpenBao: authenticating with ${BAO_ADDR}" >&2

    ## Step 2a: Resolve BAO TLS vars (auto-detect base64/PEM/file paths → temp files)
    resolve_tls_var() {
        local var_name="$1"
        local var_value="${!var_name:-}"
        [[ -z "${var_value}" ]] && return 0
        # File path — use as-is
        [[ -f "${var_value}" ]] && return 0
        local tmp_file
        tmp_file=$(mktemp "${KEY_DIR}/${var_name}.XXXXXX")
        if resolve_secret_to_file "${var_value}" "${tmp_file}"; then
            export "${var_name}=${tmp_file}"
        else
            rm -f "${tmp_file}"
        fi
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
        echo "ERROR: BAO_AGE_KEY_PATH is required when BAO_ADDR is set (e.g., sops/d2-admin/myserver-production)" >&2
        exit 1
    fi

    ## Debug: show all certificates in the client cert chain if present
    if [[ -n "${BAO_CLIENT_CERT:-}" && -f "${BAO_CLIENT_CERT}" ]]; then
        echo "## OpenBao: client certificate chain (${BAO_CLIENT_CERT}):" >&2
        CERT_NUM=0
        while read -r line; do
            if [[ "${line}" == "-----BEGIN CERTIFICATE-----" ]]; then
                CERT_NUM=$((CERT_NUM + 1))
                CERT_TMP=$(mktemp)
            fi
            [[ -n "${CERT_TMP:-}" ]] && echo "${line}" >> "${CERT_TMP}"
            if [[ "${line}" == "-----END CERTIFICATE-----" ]]; then
                echo "##   Certificate #${CERT_NUM}:" >&2
                openssl x509 -in "${CERT_TMP}" -noout -subject -issuer -dates -ext subjectAltName 2>&1 | sed 's/^/##     /' >&2
                rm -f "${CERT_TMP}"
                unset CERT_TMP
            fi
        done < "${BAO_CLIENT_CERT}"
    fi

    ## Step 2b: AppRole authentication via curl → get BAO_TOKEN
    echo "## OpenBao: logging in via AppRole" >&2
    BAO_NAMESPACE_HEADER=()
    [[ -n "${BAO_NAMESPACE:-}" ]] && BAO_NAMESPACE_HEADER=(-H "X-Vault-Namespace: ${BAO_NAMESPACE}")
    echo "## OpenBao: curl ${BAO_CURL_FLAGS[*]} ${BAO_NAMESPACE_HEADER[*]:-} --request POST --data '{\"role_id\":\"***\",\"secret_id\":\"***\"}' ${BAO_ADDR}/v1/${BAO_AUTH_PATH}/login" >&2
    LOGIN_HTTP_CODE=0
    LOGIN_RESPONSE=$(curl -v -w '\n%{http_code}' "${BAO_CURL_FLAGS[@]}" "${BAO_NAMESPACE_HEADER[@]}" \
        --request POST \
        --data "{\"role_id\":\"${BAO_ROLE_ID}\",\"secret_id\":\"${BAO_SECRET_ID}\"}" \
        "${BAO_ADDR}/v1/${BAO_AUTH_PATH}/login") || echo "## OpenBao: curl exit code $?" >&2
    LOGIN_HTTP_CODE=$(echo "${LOGIN_RESPONSE}" | tail -1)
    LOGIN_RESPONSE=$(echo "${LOGIN_RESPONSE}" | sed '$d')
    if [[ "${LOGIN_HTTP_CODE}" -ge 400 ]] 2>/dev/null; then
        echo "ERROR: OpenBao AppRole login failed (HTTP ${LOGIN_HTTP_CODE})" >&2
        echo "${LOGIN_RESPONSE}" >&2
        exit 1
    fi
    BAO_TOKEN=$(echo "${LOGIN_RESPONSE}" | jq -r '.auth.client_token')
    if [[ -z "${BAO_TOKEN}" || "${BAO_TOKEN}" == "null" ]]; then
        echo "ERROR: OpenBao AppRole login returned unexpected response" >&2
        echo "${LOGIN_RESPONSE}" >&2
        exit 1
    fi
    echo "## OpenBao: authenticated successfully" >&2

    ## Step 2c: Retrieve AGE key from KV store → write to temp file, set SOPS_AGE_KEY_FILE
    echo "## OpenBao: retrieving AGE key from ${BAO_KV_MOUNT}/data/${BAO_AGE_KEY_PATH}" >&2
    AGE_HTTP_CODE=0
    AGE_RESPONSE=$(curl -s -w '\n%{http_code}' "${BAO_CURL_FLAGS[@]}" "${BAO_NAMESPACE_HEADER[@]}" \
        -H "X-Vault-Token: ${BAO_TOKEN}" \
        "${BAO_ADDR}/v1/${BAO_KV_MOUNT}/data/${BAO_AGE_KEY_PATH}") || true
    AGE_HTTP_CODE=$(echo "${AGE_RESPONSE}" | tail -1)
    AGE_RESPONSE=$(echo "${AGE_RESPONSE}" | sed '$d')
    if [[ "${AGE_HTTP_CODE}" -ge 400 ]] 2>/dev/null; then
        echo "ERROR: Failed to retrieve AGE key (HTTP ${AGE_HTTP_CODE})" >&2
        echo "  URL: ${BAO_ADDR}/v1/${BAO_KV_MOUNT}/data/${BAO_AGE_KEY_PATH}" >&2
        echo "${AGE_RESPONSE}" >&2
        exit 1
    fi
    AGE_KEY=$(echo "${AGE_RESPONSE}" | jq -r '.data.data.key')
    if [[ -z "${AGE_KEY}" || "${AGE_KEY}" == "null" ]]; then
        echo "ERROR: AGE key not found in OpenBao response (missing .data.data.key)" >&2
        echo "  URL: ${BAO_ADDR}/v1/${BAO_KV_MOUNT}/data/${BAO_AGE_KEY_PATH}" >&2
        echo "${AGE_RESPONSE}" >&2
        exit 1
    fi
    AGE_KEY_FILE=$(mktemp "${KEY_DIR}/age-key.XXXXXX")
    echo "${AGE_KEY}" > "${AGE_KEY_FILE}"
    chmod 600 "${AGE_KEY_FILE}"
    export SOPS_AGE_KEY_FILE="${AGE_KEY_FILE}"
    echo "## OpenBao: AGE key retrieved" >&2

    ## Step 2d: Sign SSH public key via SSH secrets engine → write certificate
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

## Step 2.5: Decrypt passphrase-protected AGE key (if needed)
if [[ -n "${SOPS_AGE_KEY_FILE:-}" && -f "${SOPS_AGE_KEY_FILE}" ]]; then
    if head -1 "${SOPS_AGE_KEY_FILE}" | grep -q '^age-encryption.org'; then
        echo "## AGE key is passphrase-protected, decrypting..." >&2
        DECRYPTED_AGE_KEY=$(mktemp)
        if ! age -d "${SOPS_AGE_KEY_FILE}" > "${DECRYPTED_AGE_KEY}"; then
            rm -f "${DECRYPTED_AGE_KEY}"
            echo "ERROR: failed to decrypt AGE key" >&2
            exit 1
        fi
        chmod 600 "${DECRYPTED_AGE_KEY}"
        export SOPS_AGE_KEY_FILE="${DECRYPTED_AGE_KEY}"
        echo "## AGE key decrypted" >&2
    fi
fi

## Step 3: SOPS config file loading (only runs if SOPS_CONFIG_FILE is set)
echo "## Step 3: SOPS config loading" >&2
if [[ -n "${SOPS_CONFIG_FILE:-}" ]]; then
    echo "## Loading SOPS config from ${SOPS_CONFIG_FILE}" >&2
    if [[ ! -f "${SOPS_CONFIG_FILE}" ]]; then
        echo "ERROR: SOPS_CONFIG_FILE not found: ${SOPS_CONFIG_FILE}" >&2
        exit 1
    fi
    SOPS_DECRYPTED=$(sops decrypt --input-type dotenv --output-type dotenv \
        --filename-override export.env "${SOPS_CONFIG_FILE}")

    # Delete AGE key temp file after decryption (unless save-on-exit needs it)
    if [[ "${SOPS_SAVE_ON_EXIT:-}" != "true" ]]; then
        if [[ -n "${AGE_KEY_FILE:-}" && -f "${AGE_KEY_FILE}" ]]; then
            rm -f "${AGE_KEY_FILE}"
            unset SOPS_AGE_KEY_FILE
        fi
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

## Step 4: Validate DOCKER_CONTEXT (may come from SOPS config, container env, or SOPS filename)
echo "## Step 4: Validating DOCKER_CONTEXT" >&2
if [[ -n "${SOPS_CONFIG_FILE:-}" ]]; then
    # Always prefer SOPS-derived context name (container env may have stale/invalid names)
    DOCKER_CONTEXT="$(basename "${SOPS_CONFIG_FILE}" .sops.env)"
elif [[ -z "${DOCKER_CONTEXT:-}" ]]; then
    DOCKER_CONTEXT="${SSH_HOST:-}"
fi
if [[ -z "${DOCKER_CONTEXT}" ]]; then
    echo "ERROR: DOCKER_CONTEXT is required (set DOCKER_CONTEXT, SSH_HOST, or SOPS_CONFIG_FILE)" >&2
    exit 1
fi
# Sanitize: Docker context names must match ^[a-zA-Z0-9][a-zA-Z0-9_.+-]+$
DOCKER_CONTEXT="${DOCKER_CONTEXT#"${DOCKER_CONTEXT%%[a-zA-Z0-9]*}"}"
export DOCKER_CONTEXT
echo "## DOCKER_CONTEXT=${DOCKER_CONTEXT}" >&2

# Hydrate SSH_KNOWN_HOSTS from env (file path, plain text, or base64)
# Done here (after SOPS decryption) so vars from encrypted config are available
if [[ -n "${SSH_KNOWN_HOSTS:-}" && ! -s "${KEY_DIR}/known_hosts" ]]; then
    echo "## SSH: loading known_hosts from SSH_KNOWN_HOSTS env var" >&2
    resolve_secret_to_file "${SSH_KNOWN_HOSTS}" "${KEY_DIR}/known_hosts"
fi

## Step 5: Validate SSH vars + write SSH config (SSH_HOST may now come from SOPS)
echo "## Step 5: Setting up SSH config" >&2
if [[ -z "${SSH_HOST:-}" ]]; then
    echo "ERROR: SSH_HOST is required (set via container env or SOPS config)" >&2
    exit 1
fi
SSH_USER="${SSH_USER:-root}"
SSH_PORT="${SSH_PORT:-22}"
echo "## SSH target: ${SSH_USER}@${SSH_HOST}:${SSH_PORT}" >&2

if [[ -s "${KEY_DIR}/known_hosts" ]]; then
    echo "## SSH known_hosts already provided, skipping ssh-keyscan" >&2
elif [[ "${SSH_KEY_SCAN:-}" != "false" ]]; then
    echo "## Running ssh-keyscan for ${SSH_HOST}:${SSH_PORT}" >&2
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
echo "## SSH config written" >&2

## Step 6: Create and activate Docker context
echo "## Step 6: Creating Docker context '${DOCKER_CONTEXT}'" >&2
## Use SSH config alias so Docker inherits UserKnownHostsFile, CertificateFile, etc.
if ! docker context create "${DOCKER_CONTEXT}" \
    --docker "host=ssh://${DOCKER_CONTEXT}" >/dev/null 2>&1; then
    echo "## Docker context '${DOCKER_CONTEXT}' already exists (ok)" >&2
fi
if ! docker context use "${DOCKER_CONTEXT}" >/dev/null 2>&1; then
    echo "ERROR: Failed to activate Docker context '${DOCKER_CONTEXT}'" >&2
    echo "## Available Docker contexts:" >&2
    docker context ls >&2
    exit 1
fi
echo "## Docker context activated" >&2

## Step 7: Create root .env and distribute env vars via restore-env
echo "## Step 7: Running restore-env" >&2
cd "${ROOT_DIR}"
cp -n .env-dist ".env_${DOCKER_CONTEXT}"
if ! env | d.rymcg.tech restore-env --yes; then
    echo "WARNING: restore-env had errors (some vars may need reconfiguration)" >&2
fi

## Step 8: Ensure explicitly requested projects have env files
echo "## Step 8: Checking requested project env files" >&2
if [[ -n "${PROJECTS:-}" ]]; then
    IFS=, read -ra _requested_projects <<< "${PROJECTS}"
    for project_name in "${_requested_projects[@]}"; do
        env_file="${project_name}/.env_${DOCKER_CONTEXT}_default"
        if [[ ! -f "${env_file}" ]]; then
            echo "## Creating ${env_file} from .env-dist" >&2
            cp "${project_name}/.env-dist" "${env_file}"
        fi
    done
fi

## Step 9: Check that the target project has an env file before exec
echo "## Step 9: Validating target project" >&2
_cmd_args=("$@")
for i in "${!_cmd_args[@]}"; do
    if [[ "${_cmd_args[$i]}" == "make" && $((i+1)) -lt ${#_cmd_args[@]} ]]; then
        _target_project="${_cmd_args[$((i+1))]}"
        if [[ -d "${ROOT_DIR}/${_target_project}" && -f "${ROOT_DIR}/${_target_project}/.env-dist" ]]; then
            _target_env="${ROOT_DIR}/${_target_project}/.env_${DOCKER_CONTEXT}_default"
            if [[ ! -f "${_target_env}" ]]; then
                echo "ERROR: ${_target_env} not found." >&2
                echo "  The project '${_target_project}' was not included in the SOPS config (${SOPS_CONFIG_FILE:-unset})." >&2
                echo "  Add it via: make config → Add project → ${_target_project}" >&2
                exit 1
            fi
        fi
        break
    fi
done

## Step 10: Exec the command
echo "## Step 10: Executing: $*" >&2
unset DOCKER_CONTEXT
exec "$@"
