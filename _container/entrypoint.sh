#!/usr/bin/env bash
## d.rymcg.tech workstation Docker entrypoint
## Handles SSH keys, OpenBao auth, SOPS decryption, and Docker context setup.
set -eo pipefail

ROOT_DIR=/home/user/git/vendor/enigmacurry/d.rymcg.tech
BIN="${ROOT_DIR}/_scripts"

## Step 0: Set up runtime user with host UID/GID
RUNTIME_UID="${HOST_UID:-1000}"
RUNTIME_GID="${HOST_GID:-1000}"
RUNTIME_USER="user"
RUNTIME_HOME="/home/user"

# Update user/group to match host UID/GID
sed -i "s/^user:x:[0-9]*:[0-9]*/user:x:${RUNTIME_UID}:${RUNTIME_GID}/" /etc/passwd
sed -i "s/^user:x:[0-9]*/user:x:${RUNTIME_GID}/" /etc/group

# Fix ownership of writable directories (non-bind-mounted only).
# .config/d.rymcg.tech may contain bind-mounted secrets (age key, SOPS config)
# that must stay owned by root — do NOT recurse into it.
chown "${RUNTIME_UID}:${RUNTIME_GID}" "${RUNTIME_HOME}"
chown "${RUNTIME_UID}:${RUNTIME_GID}" \
    "${RUNTIME_HOME}/.config" \
    "${RUNTIME_HOME}/.config/d.rymcg.tech" \
    2>/dev/null || true
chown -R "${RUNTIME_UID}:${RUNTIME_GID}" \
    "${RUNTIME_HOME}/.ssh" \
    "${RUNTIME_HOME}/.local" \
    "${RUNTIME_HOME}/.cache" \
    "${ROOT_DIR}" \
    /run/secrets/ssh \
    2>/dev/null || true

## Set up PATH so the d.rymcg.tech CLI works
export PATH="${ROOT_DIR}/_scripts/user:${PATH}"

## Logging: suppress unless DRT_VERBOSE=true
if [[ "${DRT_VERBOSE:-}" == "true" ]]; then
    log() { echo "$@" >&2; }
    CURL_VERBOSE=(-v)
    echo "## Entrypoint started (uid=$(id -u), runtime=${RUNTIME_UID}:${RUNTIME_GID}, args: $*)" >&2
else
    log() { :; }
    CURL_VERBOSE=(-s)
fi


## Short-circuit: "drt" with no args outputs itself (for alias extraction);
## "drt <args>" execs directly (no entrypoint setup needed)
if [[ "${1:-}" == "drt" ]]; then
    if [[ $# -eq 1 ]]; then
        exec su-exec "${RUNTIME_USER}" /opt/drt --extract
    fi
    shift
    exec su-exec "${RUNTIME_USER}" /opt/drt "$@"
fi

## Preflight: detect unconfigured container
if [[ "${DOCKER:-}" != "false" && -z "${SSH_HOST:-}" && -z "${SOPS_CONFIG_FILE:-}" && -z "${BAO_ADDR:-}" && -z "${DOCKER_CONTEXT:-}" ]]; then
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
    awk -v img="${DRT_IMAGE:-localhost/d-rymcg-tech}" '/^###/ { if (in_block) { in_block=0 } else { in_block=1; buf="" }; next } in_block { sub(/^# ?/, ""); gsub(/@@DRT_IMAGE@@/, img); buf = buf "##    " $0 "\n" } END { printf "%s", buf }' /opt/drt >&2
    echo "##" >&2
    echo "##    == Local shell (no remote Docker host) ==" >&2
    echo "##    podman run --rm -it -e DOCKER=false ${DRT_IMAGE:-localhost/d-rymcg-tech}" >&2
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
        # Auto-detect gzip (magic bytes 1f 8b)
        if [[ $(echo "${value}" | base64 -d | od -A n -N 2 -t x1 | tr -d ' ') == "1f8b" ]]; then
            echo "${value}" | base64 -d | gunzip > "${target}"
        else
            echo "${value}" | base64 -d > "${target}"
        fi
    # Plain text (e.g. known_hosts content)
    else
        echo "${value}" > "${target}"
    fi
    chmod 600 "${target}"
}

###############################################################################
# OpenBao functions (extracted for conditional ordering)
###############################################################################

## Resolve BAO TLS vars (auto-detect base64/PEM/file paths → temp files)
resolve_bao_tls() {
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

    BAO_NAMESPACE_HEADER=()
    [[ -n "${BAO_NAMESPACE:-}" ]] && BAO_NAMESPACE_HEADER=(-H "X-Vault-Namespace: ${BAO_NAMESPACE}")

    ## Debug: show all certificates in the client cert chain if present
    if [[ -n "${BAO_CLIENT_CERT:-}" && -f "${BAO_CLIENT_CERT}" ]]; then
        log "## OpenBao: client certificate chain (${BAO_CLIENT_CERT}):"
        CERT_NUM=0
        while read -r line; do
            if [[ "${line}" == "-----BEGIN CERTIFICATE-----" ]]; then
                CERT_NUM=$((CERT_NUM + 1))
                CERT_TMP=$(mktemp)
            fi
            [[ -n "${CERT_TMP:-}" ]] && echo "${line}" >> "${CERT_TMP}"
            if [[ "${line}" == "-----END CERTIFICATE-----" ]]; then
                log "##   Certificate #${CERT_NUM}:"
                openssl x509 -in "${CERT_TMP}" -noout -subject -issuer -dates -ext subjectAltName 2>&1 | sed 's/^/##     /' | while IFS= read -r certline; do log "${certline}"; done
                rm -f "${CERT_TMP}"
                unset CERT_TMP
            fi
        done < "${BAO_CLIENT_CERT}"
    fi
}

## AppRole authentication via curl → set BAO_TOKEN
openbao_auth() {
    log "## OpenBao: authenticating with ${BAO_ADDR}"

    # Validate required vars
    if [[ -z "${BAO_ROLE_ID:-}" ]]; then
        echo "ERROR: BAO_ROLE_ID is required when BAO_ADDR is set" >&2
        exit 1
    fi
    if [[ -z "${BAO_SECRET_ID:-}" ]]; then
        echo "ERROR: BAO_SECRET_ID is required when BAO_ADDR is set" >&2
        exit 1
    fi

    resolve_bao_tls

    log "## OpenBao: logging in via AppRole"
    log "## OpenBao: curl ${BAO_CURL_FLAGS[*]} ${BAO_NAMESPACE_HEADER[*]:-} --request POST --data '{\"role_id\":\"***\",\"secret_id\":\"***\"}' ${BAO_ADDR}/v1/${BAO_AUTH_PATH}/login"
    LOGIN_HTTP_CODE=0
    LOGIN_RESPONSE=$(curl "${CURL_VERBOSE[@]}" -w '\n%{http_code}' "${BAO_CURL_FLAGS[@]}" "${BAO_NAMESPACE_HEADER[@]}" \
        --request POST \
        --data "$(jq -n --arg r "${BAO_ROLE_ID}" --arg s "${BAO_SECRET_ID}" '{role_id:$r,secret_id:$s}')" \
        "${BAO_ADDR}/v1/${BAO_AUTH_PATH}/login") || log "## OpenBao: curl exit code $?"
    LOGIN_HTTP_CODE=$(echo "${LOGIN_RESPONSE}" | tail -1)
    LOGIN_RESPONSE=$(echo "${LOGIN_RESPONSE}" | sed '$d')
    if [[ "${LOGIN_HTTP_CODE}" -ge 400 ]] 2>/dev/null; then
        echo "ERROR: OpenBao AppRole login failed (HTTP ${LOGIN_HTTP_CODE})" >&2
        echo "${LOGIN_RESPONSE}" >&2
        if [[ "${LOGIN_HTTP_CODE}" == "503" ]] && echo "${LOGIN_RESPONSE}" | grep -qi "sealed"; then
            echo "" >&2
            echo "The OpenBao server is sealed. Unseal it first:" >&2
            echo "  drt --unseal" >&2
        fi
        exit 1
    fi
    BAO_TOKEN=$(echo "${LOGIN_RESPONSE}" | jq -r '.auth.client_token')
    if [[ -z "${BAO_TOKEN}" || "${BAO_TOKEN}" == "null" ]]; then
        echo "ERROR: OpenBao AppRole login returned unexpected response" >&2
        echo "${LOGIN_RESPONSE}" >&2
        exit 1
    fi
    log "## OpenBao: authenticated successfully"
}

## Retrieve AGE key from KV store → write to temp file, set SOPS_AGE_KEY_FILE
openbao_get_age_key() {
    if [[ -z "${BAO_AGE_KEY_PATH:-}" ]]; then
        echo "ERROR: BAO_AGE_KEY_PATH is required (e.g., sops/d2-admin/myserver-production)" >&2
        exit 1
    fi
    log "## OpenBao: retrieving AGE key from ${BAO_KV_MOUNT}/data/${BAO_AGE_KEY_PATH}"
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
    log "## OpenBao: AGE key retrieved"
}

## Sign SSH public key via SSH secrets engine → write certificate
openbao_sign_ssh() {
    log "## OpenBao: signing SSH public key via ${BAO_SSH_MOUNT}/sign/${BAO_SSH_ROLE}"
    SSH_PUBLIC_KEY=$(cat "${KEY_DIR}/id_ed25519.pub")
    SIGN_RESPONSE=$(curl -sf "${BAO_CURL_FLAGS[@]}" "${BAO_NAMESPACE_HEADER[@]}" \
        -H "X-Vault-Token: ${BAO_TOKEN}" \
        --request POST \
        --data "$(jq -n --arg k "${SSH_PUBLIC_KEY}" '{public_key:$k}')" \
        "${BAO_ADDR}/v1/${BAO_SSH_MOUNT}/sign/${BAO_SSH_ROLE}")
    SIGNED_KEY=$(echo "${SIGN_RESPONSE}" | jq -r '.data.signed_key')
    if [[ -z "${SIGNED_KEY}" || "${SIGNED_KEY}" == "null" ]]; then
        echo "ERROR: SSH certificate signing failed" >&2
        echo "${SIGN_RESPONSE}" >&2
        exit 1
    fi
    echo "${SIGNED_KEY}" > "${KEY_DIR}/id_ed25519-cert.pub"
    chmod 600 "${KEY_DIR}/id_ed25519-cert.pub"
    log "## OpenBao: SSH certificate obtained"
}

## Persist BAO connection state for on-demand re-signing by sign-ssh-cert
## NOTE: role_id/secret_id are stored in user-readable files here. Moving them
## to root-only storage with a FIFO signing helper was considered but deferred:
## in the rootless podman model there is no real privilege boundary between root
## and the runtime user (they map to the same host UID), so the added complexity
## would not provide meaningful security improvement.
persist_bao_state() {
    local BAO_STATE_DIR="${HOME}/.ssh/bao"
    mkdir -p "${BAO_STATE_DIR}"
    chmod 700 "${BAO_STATE_DIR}"

    write_state() {
        local name="$1" value="$2"
        if [[ -n "${value}" ]]; then
            echo "${value}" > "${BAO_STATE_DIR}/${name}"
        fi
    }

    write_state key_dir "${KEY_DIR}"
    write_state addr "${BAO_ADDR:-}"
    write_state token "${BAO_TOKEN:-}"
    write_state ssh_mount "${BAO_SSH_MOUNT:-}"
    write_state ssh_role "${BAO_SSH_ROLE:-}"
    write_state auth_path "${BAO_AUTH_PATH:-}"
    write_state role_id "${BAO_ROLE_ID:-}"
    write_state secret_id "${BAO_SECRET_ID:-}"
    write_state namespace "${BAO_NAMESPACE:-}"

    # Copy TLS files if they exist
    [[ -n "${BAO_CACERT:-}" && -f "${BAO_CACERT}" ]]           && cp "${BAO_CACERT}" "${BAO_STATE_DIR}/cacert"
    [[ -n "${BAO_CLIENT_CERT:-}" && -f "${BAO_CLIENT_CERT}" ]] && cp "${BAO_CLIENT_CERT}" "${BAO_STATE_DIR}/client_cert"
    [[ -n "${BAO_CLIENT_KEY:-}" && -f "${BAO_CLIENT_KEY}" ]]   && cp "${BAO_CLIENT_KEY}" "${BAO_STATE_DIR}/client_key"

    chmod 600 "${BAO_STATE_DIR}"/* 2>/dev/null || true
    log "## OpenBao: connection state persisted to ${BAO_STATE_DIR}"
}

###############################################################################
# SOPS decryption function
###############################################################################

decrypt_sops() {
    if [[ -z "${SOPS_CONFIG_FILE:-}" ]]; then
        return 0
    fi
    log "## Loading SOPS config from ${SOPS_CONFIG_FILE}"
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

    # Parse each KEY=VALUE; export only if not already set (container env wins)
    # Skip serialized data keys (__passwords__, __ssh_key__, etc.) — handled by restore-env
    while IFS= read -r line; do
        [[ -z "${line}" || "${line}" == "#"* ]] && continue
        key="${line%%=*}"
        val="${line#*=}"
        [[ "${key}" == __* ]] && continue
        # Only set if not already defined in container env (container env wins)
        if [[ -z "${!key+set}" ]]; then
            export "${key}=${val}"
        fi
    done <<< "${SOPS_DECRYPTED}"
    # Note: SOPS_DECRYPTED is kept alive for restore-env (Step 8) to receive
    # serialized data keys (__passwords__, __ssh_key__, etc.)
    log "## SOPS config loaded"
}

###############################################################################
# FIDO2 touch prompt
###############################################################################

## Check if AGE key is a FIDO2 identity and print a touch reminder
fido2_touch_prompt() {
    if [[ -n "${SOPS_AGE_KEY_FILE:-}" && -f "${SOPS_AGE_KEY_FILE}" ]]; then
        if grep -q 'AGE-PLUGIN-FIDO2-HMAC' "${SOPS_AGE_KEY_FILE}" 2>/dev/null; then
            echo "## Touch your FIDO2 key when it flashes ..." >&2
        fi
    fi
}

###############################################################################
# AGE key passphrase decryption
###############################################################################

decrypt_age_key() {
    if [[ -n "${SOPS_AGE_KEY_FILE:-}" && -f "${SOPS_AGE_KEY_FILE}" ]]; then
        if head -1 "${SOPS_AGE_KEY_FILE}" | grep -q '^age-encryption.org'; then
            log "## AGE key is passphrase-protected, decrypting..."
            # Flush any buffered TTY input so stray keypresses don't feed the passphrase prompt
            # (age reads from /dev/tty, not stdin)
            if [[ -t 0 ]]; then
                while read -t 0.1 -s -r < /dev/tty; do :; done 2>/dev/null || true
                echo "## Get ready to enter your AGE key passphrase ..." >&2
            fi
            DECRYPTED_AGE_KEY=$(mktemp)
            if ! age -d "${SOPS_AGE_KEY_FILE}" > "${DECRYPTED_AGE_KEY}"; then
                rm -f "${DECRYPTED_AGE_KEY}"
                echo "ERROR: failed to decrypt AGE key" >&2
                exit 1
            fi
            echo "## Passphrase accepted." >&2
            chmod 600 "${DECRYPTED_AGE_KEY}"
            export SOPS_AGE_KEY_FILE="${DECRYPTED_AGE_KEY}"
            log "## AGE key decrypted"
        fi
    fi
}

###############################################################################
# Main entrypoint flow
###############################################################################

## Step 1: Set up SSH key directory and credentials
log "## Step 1: Setting up SSH credentials"
KEY_DIR=/run/secrets/ssh
mkdir -p "${KEY_DIR}" 2>/dev/null || KEY_DIR=$(mktemp -d)
mkdir -p ~/.ssh
chmod 700 "${KEY_DIR}" ~/.ssh

# Hydrate SSH_KEY from env (file path, PEM, or base64)
if [[ -n "${SSH_KEY:-}" && ! -f "${KEY_DIR}/id_ed25519" ]]; then
    log "## SSH: loading key from SSH_KEY env var"
    resolve_secret_to_file "${SSH_KEY}" "${KEY_DIR}/id_ed25519"
fi

# Generate a key if none was provided or mounted
if [[ ! -f "${KEY_DIR}/id_ed25519" ]]; then
    ssh-keygen -t ed25519 -N "" -f "${KEY_DIR}/id_ed25519" -q
fi

## Step 2: Decrypt passphrase-protected AGE key (if needed)
log "## Step 2: AGE key decryption"
decrypt_age_key

## Step 3: Conditional SOPS/OpenBao resolution
echo "## Restoring environment ..." >&2
log "## Step 3: SOPS/OpenBao resolution"
BAO_USED=false

if [[ -n "${SOPS_AGE_KEY_FILE:-}" && -f "${SOPS_AGE_KEY_FILE}" ]]; then
    ## Interactive path: local AGE key available → SOPS first (may populate BAO_*)
    log "## Path: local AGE key → SOPS first"
    fido2_touch_prompt
    decrypt_sops
    echo "## SOPS config loaded" >&2
    ## After SOPS, BAO_* vars may now be set → auth + sign SSH cert if so
    if [[ -n "${BAO_ADDR:-}" && "${BAO_SKIP:-}" != "true" ]]; then
        echo "## Authenticating with OpenBao ..." >&2
        openbao_auth
        echo "## Signing SSH certificate ..." >&2
        openbao_sign_ssh
        BAO_USED=true
    elif [[ "${BAO_SKIP:-}" == "true" ]]; then
        log "## OpenBao skipped (BAO_SKIP=true), using SSH agent"
    fi
elif [[ -n "${BAO_ADDR:-}" && "${BAO_SKIP:-}" != "true" ]]; then
    ## CI path: BAO_* from container env → OpenBao first
    log "## Path: container env BAO_* → OpenBao first"
    echo "## Authenticating with OpenBao ..." >&2
    openbao_auth
    ## Get AGE key from KV if BAO_AGE_KEY_PATH is set
    if [[ -n "${BAO_AGE_KEY_PATH:-}" ]]; then
        openbao_get_age_key
        decrypt_age_key
    fi
    decrypt_sops
    echo "## SOPS config loaded" >&2
    echo "## Signing SSH certificate ..." >&2
    openbao_sign_ssh
    BAO_USED=true
else
    ## No OpenBao, just try SOPS if SOPS_CONFIG_FILE exists
    log "## Path: SOPS only (no OpenBao)"
    decrypt_sops
fi

## Derive SOPS_AGE_RECIPIENTS (public key) from the private key for export-env --encrypt
if [[ -z "${SOPS_AGE_RECIPIENTS:-}" ]]; then
    if [[ -n "${SOPS_AGE_KEY_FILE:-}" && -f "${SOPS_AGE_KEY_FILE}" ]]; then
        # FIDO2 identity files have "# recipient: age1..." comments
        if grep -q 'AGE-PLUGIN-FIDO2-HMAC' "${SOPS_AGE_KEY_FILE}" 2>/dev/null; then
            SOPS_AGE_RECIPIENTS=$(grep -o 'age1[a-z0-9-]*' "${SOPS_AGE_KEY_FILE}" 2>/dev/null | paste -sd,)
        else
            SOPS_AGE_RECIPIENTS=$(age-keygen -y "${SOPS_AGE_KEY_FILE}" 2>/dev/null || true)
        fi
    elif [[ -n "${SOPS_AGE_KEY:-}" ]]; then
        SOPS_AGE_RECIPIENTS=$(echo "${SOPS_AGE_KEY}" | age-keygen -y - 2>/dev/null || true)
    fi
    if [[ -n "${SOPS_AGE_RECIPIENTS:-}" ]]; then
        export SOPS_AGE_RECIPIENTS
        log "## SOPS_AGE_RECIPIENTS=${SOPS_AGE_RECIPIENTS}"
    fi
fi

## Step 4: Persist BAO state for on-demand re-signing (only if OpenBao was used)
if [[ "${BAO_USED}" == true ]]; then
    log "## Step 4: Persisting OpenBao state"
    persist_bao_state
else
    log "## Step 4: No OpenBao state to persist"
fi

## Step 5: Resolve DOCKER flag and validate DOCKER_CONTEXT
log "## Step 5: Resolving DOCKER flag and DOCKER_CONTEXT"
if [[ -n "${SSH_HOST:-}" ]]; then
    DOCKER=true
elif [[ "${DOCKER:-}" != "false" ]]; then
    echo "ERROR: SSH_HOST is not set. Set DOCKER=false to run without a remote Docker host." >&2
    exit 1
fi
export DOCKER
log "## DOCKER=${DOCKER}"

if [[ "${DOCKER}" == "false" ]]; then
    DOCKER_CONTEXT="local"
    log "## DOCKER=false, using DOCKER_CONTEXT=${DOCKER_CONTEXT} (not exported)"
elif [[ -n "${SOPS_CONFIG_FILE:-}" ]]; then
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
if [[ "${DOCKER}" == "true" ]]; then
    export DOCKER_CONTEXT
fi
log "## DOCKER_CONTEXT=${DOCKER_CONTEXT}"

# Rename SSH key files to context-specific names
KEY_NAME="${DOCKER_CONTEXT}"
if [[ -f "${KEY_DIR}/id_ed25519" ]]; then
    mv "${KEY_DIR}/id_ed25519" "${KEY_DIR}/${KEY_NAME}"
    [[ -f "${KEY_DIR}/id_ed25519.pub" ]] && mv "${KEY_DIR}/id_ed25519.pub" "${KEY_DIR}/${KEY_NAME}.pub"
    [[ -f "${KEY_DIR}/id_ed25519-cert.pub" ]] && mv "${KEY_DIR}/id_ed25519-cert.pub" "${KEY_DIR}/${KEY_NAME}-cert.pub"
fi
# Update BAO state with context-specific key name (Step 4 runs before context is known)
if [[ "${BAO_USED:-}" == true && -d "${RUNTIME_HOME}/.ssh/bao" ]]; then
    echo "${KEY_NAME}" > "${RUNTIME_HOME}/.ssh/bao/key_name"
fi

# Hydrate SSH_KNOWN_HOSTS from env (file path, plain text, or base64)
# Done here (after SOPS decryption) so vars from encrypted config are available
if [[ -n "${SSH_KNOWN_HOSTS:-}" && ! -s "${KEY_DIR}/known_hosts" ]]; then
    log "## SSH: loading known_hosts from SSH_KNOWN_HOSTS env var"
    resolve_secret_to_file "${SSH_KNOWN_HOSTS}" "${KEY_DIR}/known_hosts"
fi

## Step 6: Validate SSH vars + write SSH config (SSH_HOST may now come from SOPS)
log "## Step 6: Setting up SSH config"
if [[ -n "${SSH_HOST:-}" ]]; then
    SSH_USER="${SSH_USER:-root}"
    SSH_PORT="${SSH_PORT:-22}"
    log "## SSH target: ${SSH_USER}@${SSH_HOST}:${SSH_PORT}"

    if [[ -s "${KEY_DIR}/known_hosts" ]]; then
        log "## SSH known_hosts already provided, skipping ssh-keyscan"
    elif [[ -t 0 ]]; then
        log "## Interactive session: skipping ssh-keyscan (known_hosts from config)"
    elif [[ "${SSH_KEY_SCAN:-}" != "false" ]]; then
        log "## Running ssh-keyscan for ${SSH_HOST}:${SSH_PORT}"
        if ! ssh-keyscan -p "${SSH_PORT}" "${SSH_HOST}" >> "${KEY_DIR}/known_hosts" 2>/dev/null; then
            echo "ERROR: ssh-keyscan failed for ${SSH_HOST}:${SSH_PORT} (set SSH_KEY_SCAN=false to skip)" >&2
            exit 1
        fi
    fi

    # Write SSH config to ~/.ssh/config-drt (auto-generated; user config is in ~/.ssh/config)
    if [[ "${BAO_USED}" == true ]]; then
        # OpenBao signs certs for the container-generated key; disable SSH agent
        unset SSH_AUTH_SOCK
        {
            echo "Host ${DOCKER_CONTEXT}"
            echo ""
            echo "Match host ${DOCKER_CONTEXT} exec \"sign-ssh-cert\""
            echo "    HostName ${SSH_HOST}"
            echo "    User ${SSH_USER}"
            echo "    Port ${SSH_PORT}"
            echo "    IdentityFile ${KEY_DIR}/${KEY_NAME}"
            echo "    IdentitiesOnly yes"
            echo "    UserKnownHostsFile ${KEY_DIR}/known_hosts"
            echo "    CertificateFile ${KEY_DIR}/${KEY_NAME}-cert.pub"
            echo "    ConnectTimeout ${SSH_CONNECT_TIMEOUT:-30}"
        } > ~/.ssh/config-drt
    else
        if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
            log "## SSH auth: using forwarded SSH agent"
        fi
        {
            echo "Host ${DOCKER_CONTEXT}"
            echo "    HostName ${SSH_HOST}"
            echo "    User ${SSH_USER}"
            echo "    Port ${SSH_PORT}"
            echo "    IdentityFile ${KEY_DIR}/${KEY_NAME}"
            echo "    UserKnownHostsFile ${KEY_DIR}/known_hosts"
            # Include CertificateFile only if an SSH certificate was obtained
            if [[ -f "${KEY_DIR}/${KEY_NAME}-cert.pub" ]]; then
                echo "    CertificateFile ${KEY_DIR}/${KEY_NAME}-cert.pub"
            fi
            echo "    ConnectTimeout ${SSH_CONNECT_TIMEOUT:-30}"
        } > ~/.ssh/config-drt
    fi

    # Add ControlMaster for interactive sessions (reuse SSH connections)
    if [[ -t 0 ]]; then
        {
            echo ""
            echo "Host *"
            echo "    ControlMaster auto"
            echo "    ControlPersist yes"
            echo "    ControlPath /tmp/ssh-%u-%r@%h:%p"
        } >> ~/.ssh/config-drt
    fi
    chmod 600 ~/.ssh/config-drt
    log "## SSH config-drt written"

    ## Step 7: Create and activate Docker context
    log "## Step 7: Creating Docker context '${DOCKER_CONTEXT}'"
    ## Use SSH config alias so Docker inherits UserKnownHostsFile, CertificateFile, etc.
    if ! docker context create "${DOCKER_CONTEXT}" \
        --docker "host=ssh://${DOCKER_CONTEXT}" >/dev/null 2>&1; then
        log "## Docker context '${DOCKER_CONTEXT}' already exists (ok)"
    fi
    if ! docker context use "${DOCKER_CONTEXT}" >/dev/null 2>&1; then
        echo "ERROR: Failed to activate Docker context '${DOCKER_CONTEXT}'" >&2
        echo "## Available Docker contexts:" >&2
        docker context ls >&2
        exit 1
    fi
    log "## Docker context activated"
else
    log "## No SSH_HOST configured, skipping SSH and Docker context setup"
    touch ~/.ssh/config-drt
    chmod 600 ~/.ssh/config-drt
fi

## Step 8: Create root .env and distribute env vars via restore-env
## Detect bind mount at ROOT_DIR — secrets would persist on host after container exit
if mountpoint -q "${ROOT_DIR}" 2>/dev/null; then
    DRT_BIND_MOUNT=true
    echo "" >&2
    echo "WARNING: ${ROOT_DIR} is a bind mount!" >&2
    echo "Decrypted secrets (.env_* files) will persist on the host filesystem" >&2
    echo "after this container exits unless cleaned up." >&2
    echo "" >&2
    if [[ -t 0 ]]; then
        printf "Continue decrypting secrets to this location? [y/N] " >&2
        read -r _bind_mount_answer </dev/tty
        if [[ "${_bind_mount_answer}" != [yY]* ]]; then
            echo "Aborted." >&2
            exit 1
        fi
    else
        echo "Non-interactive session: aborting for safety." >&2
        echo "Remove the bind mount at ${ROOT_DIR} or run interactively to confirm." >&2
        exit 1
    fi
else
    DRT_BIND_MOUNT=false
fi
log "## Step 8: Running restore-env"
cd "${ROOT_DIR}"
cp -n .env-dist ".env_${DOCKER_CONTEXT}"
if [[ "${DRT_VERBOSE:-}" == "true" ]]; then
    if ! { env; echo "${SOPS_DECRYPTED:-}"; } | DOCKER_CONTEXT="${DOCKER_CONTEXT}" d.rymcg.tech restore-env --yes; then
        echo "" >&2
        echo "WARNING: restore-env had errors (some vars may need reconfiguration)" >&2
    fi
else
    if ! { env; echo "${SOPS_DECRYPTED:-}"; } | DOCKER_CONTEXT="${DOCKER_CONTEXT}" d.rymcg.tech restore-env --yes 2>/dev/null; then
        echo "" >&2
        echo "WARNING: restore-env had errors (some vars may need reconfiguration)" >&2
    fi
fi

# Ensure ~/.ssh/config includes config-drt (after restore-env, which may restore ~/.ssh/config)
if [[ ! -f ~/.ssh/config ]]; then
    echo "Include config-drt" > ~/.ssh/config
elif ! grep -q 'Include config-drt' ~/.ssh/config; then
    sed -i '1i Include config-drt' ~/.ssh/config
fi
chmod 600 ~/.ssh/config

## Step 9: Ensure explicitly requested projects have env files
log "## Step 9: Checking requested project env files"
if [[ -n "${PROJECTS:-}" ]]; then
    IFS=, read -ra _requested_projects <<< "${PROJECTS}"
    for project_name in "${_requested_projects[@]}"; do
        env_file="${project_name}/.env_${DOCKER_CONTEXT}_default"
        if [[ ! -f "${env_file}" ]]; then
            log "## Creating ${env_file} from .env-dist"
            cp "${project_name}/.env-dist" "${env_file}"
        fi
    done
fi

## Step 10: Check that the target project has an env file before exec
log "## Step 10: Validating target project"
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

## Step 11: Fix ownership and drop privileges
log "## Step 11: Fixing ownership and dropping to ${RUNTIME_USER} (${RUNTIME_UID}:${RUNTIME_GID})"

# Fix ownership of files created during entrypoint setup
chown -R "${RUNTIME_UID}:${RUNTIME_GID}" \
    "${RUNTIME_HOME}/.ssh" \
    "${RUNTIME_HOME}/.docker" \
    "${RUNTIME_HOME}/.config/doctl" \
    /run/secrets/ssh \
    2>/dev/null || true

# For save-on-exit: decrypt SOPS config to a user-writable plaintext copy.
# The runtime user reads/writes plaintext; on save, the root helper encrypts
# and writes back to the bind mount. Only root has the AGE key.
# We do NOT chown bind-mounted files — in rootless podman that changes host
# ownership to subuids.
if [[ "${SOPS_SAVE_ON_EXIT:-}" == "true" && -n "${SOPS_CONFIG_FILE:-}" && -f "${SOPS_CONFIG_FILE}" ]]; then
    _SOPS_BIND_PATH="${SOPS_CONFIG_FILE}"
    _SOPS_USER_COPY=$(mktemp /tmp/sops-config.XXXXXX)
    _SOPS_SAVE_REQUEST=$(mktemp -u /tmp/sops-req.XXXXXX)
    _SOPS_SAVE_RESPONSE=$(mktemp -u /tmp/sops-res.XXXXXX)
    # Write the already-decrypted SOPS config into the user copy.
    # SOPS_DECRYPTED was populated by decrypt_sops() earlier.
    if [[ -n "${SOPS_DECRYPTED:-}" ]]; then
        echo "${SOPS_DECRYPTED}" > "${_SOPS_USER_COPY}"
    else
        sops decrypt --input-type dotenv --output-type dotenv \
            --filename-override export.env "${_SOPS_BIND_PATH}" > "${_SOPS_USER_COPY}"
    fi
    chown "${RUNTIME_UID}:${RUNTIME_GID}" "${_SOPS_USER_COPY}"
    chmod 600 "${_SOPS_USER_COPY}"
    export SOPS_CONFIG_FILE="${_SOPS_USER_COPY}"
    export _SOPS_BIND_PATH _SOPS_SAVE_REQUEST _SOPS_SAVE_RESPONSE

    # Create FIFOs for synchronous save-back signaling
    mkfifo "${_SOPS_SAVE_REQUEST}" "${_SOPS_SAVE_RESPONSE}"
    # FIFOs need read+write from both root (background save helper) and
    # the runtime user. In rootless podman these map to the same host UID,
    # so 666 on the transient FIFOs is fine — actual secret data lives in
    # the 600-permissioned user copy, not in the signaling channel.
    chmod 666 "${_SOPS_SAVE_REQUEST}" "${_SOPS_SAVE_RESPONSE}"

    # Background root process: waits for save request, re-encrypts the
    # user copy back to the bind mount. Uses `sops edit` with a custom
    # EDITOR so only changed values get new ciphertext — unchanged values
    # keep their nonces, producing minimal git diffs.
    _SOPS_EDITOR="/tmp/sops-editor"
    cat > "${_SOPS_EDITOR}" << EDITOREOF
#!/bin/sh
cp "${_SOPS_USER_COPY}" "\$1"
EDITOREOF
    chmod +x "${_SOPS_EDITOR}"
    (
        while read -r cmd < "${_SOPS_SAVE_REQUEST}"; do
            if [[ "${cmd}" == "fix-perms" ]]; then
                # Fix ownership of config dirs that may have been created by podman cp
                for _d in "${HOME}/.config/doctl" "${HOME}/.aws" "${HOME}/.config/gh" \
                          "${HOME}/.config/rclone" "${HOME}/.mc" "${HOME}/.config/wireguard" \
                          "${HOME}/.gnupg" "${HOME}/.ssh"; do
                    chown -R "${RUNTIME_UID}:${RUNTIME_GID}" "${_d}" 2>/dev/null || true
                done
                # d.rymcg.tech dir: exclude config/, keys/, and *.sops.env (bind-mounted from host)
                find "${HOME}/.config/d.rymcg.tech" -not -path '*/config/*' -not -path '*/keys/*' \
                    -not -name '*.sops.env' \
                    -exec chown "${RUNTIME_UID}:${RUNTIME_GID}" {} + 2>/dev/null || true
                echo "ok" > "${_SOPS_SAVE_RESPONSE}"
            elif [[ "${cmd}" == "save" ]]; then
                if [[ -n "${SOPS_AGE_KEY_FILE:-}" && -f "${SOPS_AGE_KEY_FILE}" ]] && \
                   grep -q 'AGE-PLUGIN-FIDO2-HMAC' "${SOPS_AGE_KEY_FILE}" 2>/dev/null; then
                    echo "## Touch your FIDO2 key when it flashes ..." >&2
                fi
                # Edit a copy to avoid sops rewriting the bind-mounted file
                # (which would change host ownership to container root's mapped UID)
                _sops_work="/tmp/sops-save-work.sops.env"
                cp "${_SOPS_BIND_PATH}" "${_sops_work}"
                if EDITOR="${_SOPS_EDITOR}" sops \
                       --input-type dotenv --output-type dotenv \
                       "${_sops_work}" && \
                   cat "${_sops_work}" > "${_SOPS_BIND_PATH}" && \
                   rm -f "${_sops_work}"; then
                    echo "ok" > "${_SOPS_SAVE_RESPONSE}"
                else
                    echo "fail" > "${_SOPS_SAVE_RESPONSE}"
                fi
            elif [[ "${cmd}" == "quit" ]]; then
                break
            fi
        done
        rm -f "${_SOPS_SAVE_REQUEST}" "${_SOPS_SAVE_RESPONSE}" "${_SOPS_EDITOR}"
    ) &
    log "## SOPS save-on-exit helper started (PID $!)"
fi
unset SOPS_DECRYPTED

# Fix ownership of env files and passwords.json created by restore-env
find "${ROOT_DIR}" \( -name ".env_*" -o -name "passwords.json" \) -exec chown "${RUNTIME_UID}:${RUNTIME_GID}" {} + 2>/dev/null || true
# chown the entire drt config dir (covers gumdrop-presets, startup.sh, etc.)
# Exclude config/, keys/, and *.sops.env (bind-mounted from host)
find "${HOME}/.config/d.rymcg.tech" -not -path '*/config/*' -not -path '*/keys/*' \
    -not -name '*.sops.env' \
    -exec chown "${RUNTIME_UID}:${RUNTIME_GID}" {} + 2>/dev/null || true
chown -R "${RUNTIME_UID}:${RUNTIME_GID}" "${HOME}/.config/doctl" 2>/dev/null || true
chown -R "${RUNTIME_UID}:${RUNTIME_GID}" "${HOME}/.aws" 2>/dev/null || true
chown -R "${RUNTIME_UID}:${RUNTIME_GID}" "${HOME}/.config/gh" 2>/dev/null || true
chown -R "${RUNTIME_UID}:${RUNTIME_GID}" "${HOME}/.config/rclone" 2>/dev/null || true
chown -R "${RUNTIME_UID}:${RUNTIME_GID}" "${HOME}/.mc" 2>/dev/null || true
chown -R "${RUNTIME_UID}:${RUNTIME_GID}" "${HOME}/.config/wireguard" 2>/dev/null || true
chown -R "${RUNTIME_UID}:${RUNTIME_GID}" "${HOME}/.gnupg" 2>/dev/null || true
chown -R "${RUNTIME_UID}:${RUNTIME_GID}" "${HOME}/.kube" 2>/dev/null || true
chown -R "${RUNTIME_UID}:${RUNTIME_GID}" "${HOME}/.config/helm" 2>/dev/null || true
chown "${RUNTIME_UID}:${RUNTIME_GID}" "${HOME}/.bashrc.local" 2>/dev/null || true
chown "${RUNTIME_UID}:${RUNTIME_GID}" "${HOME}/.motd" 2>/dev/null || true

# Make SSH agent socket accessible to the runtime user via socat proxy.
# We cannot chown/chmod the bind-mounted socket — in rootless podman that
# changes the host file's ownership to a sub-UID.  Instead, create a new
# socket owned by the runtime user that relays to the original.
if [[ -S "${SSH_AUTH_SOCK:-}" ]]; then
    _PROXY_SOCK="/run/ssh-agent-user.sock"
    socat "UNIX-LISTEN:${_PROXY_SOCK},fork,user=${RUNTIME_UID},group=${RUNTIME_GID},mode=600" \
          "UNIX-CONNECT:${SSH_AUTH_SOCK}" &
    export SSH_AUTH_SOCK="${_PROXY_SOCK}"
fi

# Make Wayland/PipeWire sockets accessible to the runtime user.
# We cannot use socat here because Wayland uses SCM_RIGHTS to pass file
# descriptors (GPU buffers, DMA-BUF handles) which socat does not forward.
# Instead: chmod the bind-mounted socket (safe — host XDG_RUNTIME_DIR is
# already mode 700) and symlink it into a user-owned runtime directory.
# Apps like Firefox need to create their own sockets in XDG_RUNTIME_DIR.
if [[ -S "/tmp/runtime-dir/${WAYLAND_DISPLAY:-}" ]] || [[ -S "/tmp/runtime-dir/pipewire-0" ]]; then
    _USER_RUNTIME="/run/user-runtime"
    mkdir -p "${_USER_RUNTIME}"
    chown "${RUNTIME_UID}:${RUNTIME_GID}" "${_USER_RUNTIME}"
    chmod 700 "${_USER_RUNTIME}"
    export XDG_RUNTIME_DIR="${_USER_RUNTIME}"
fi

if [[ -S "/tmp/runtime-dir/${WAYLAND_DISPLAY:-}" ]]; then
    chmod 666 "/tmp/runtime-dir/${WAYLAND_DISPLAY}"
    ln -sf "/tmp/runtime-dir/${WAYLAND_DISPLAY}" "${_USER_RUNTIME}/wayland-0"
    export WAYLAND_DISPLAY="wayland-0"
    log "## Wayland: ${_USER_RUNTIME}/wayland-0 → /tmp/runtime-dir/${WAYLAND_DISPLAY}"
fi

if [[ -S "/tmp/runtime-dir/pipewire-0" ]]; then
    chmod 666 "/tmp/runtime-dir/pipewire-0"
    ln -sf "/tmp/runtime-dir/pipewire-0" "${_USER_RUNTIME}/pipewire-0"
    log "## PipeWire: ${_USER_RUNTIME}/pipewire-0 → /tmp/runtime-dir/pipewire-0"
fi

# Fix TTY ownership so the runtime user can write to /dev/stderr, /dev/stdout
if [[ -t 0 ]]; then
    chown "${RUNTIME_UID}:${RUNTIME_GID}" "$(tty)" 2>/dev/null || true
fi

# Re-initialize resolvconf if available (podman overwrites /etc/resolv.conf at startup)
if command -v resolvconf &>/dev/null; then
    resolvconf -u 2>/dev/null || true
fi

export DRT_CONTEXT="${DOCKER_CONTEXT}"
unset DOCKER_CONTEXT
cd "${HOME}"
log "## Executing: $*"
exec su-exec "${RUNTIME_USER}" "$@"
