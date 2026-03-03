#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

D="${D:-d.rymcg.tech}"

# Wrapper for interactive wizard commands. Aborts on Ctrl-C (exit 2),
# returns the wizard's exit code otherwise so || continue/break still work.
wizard() {
    local subcmd="$1"; shift
    local rc=0
    case "${subcmd}" in
        confirm|choose)
            "${D}" script wizard "${subcmd}" --cancel-code=2 "$@" || rc=$?
            ;;
        *)
            "${D}" script wizard "${subcmd}" "$@" || rc=$?
            ;;
    esac
    if [[ $rc -eq 2 || $rc -ge 128 ]]; then
        exit 130
    fi
    return $rc
}

_CFG_D_ROOT=""
_CFG_TMP_CTX=""
_cfg_cleanup() { [[ -n "${_CFG_D_ROOT}" ]] && find "${_CFG_D_ROOT}" -name ".env_${_CFG_TMP_CTX}*" -delete 2>/dev/null || true; }

cmd_config() {
    trap _cfg_cleanup EXIT

    _CFG_D_ROOT=$(cd "$(dirname "$(readlink -f "$(which ${D})")")/.." && pwd)
    _CFG_TMP_CTX="_d2cfg_$$_$(date +%s)"

    readarray -t EXISTING < <(ls config/*.sops.env 2>/dev/null | xargs -rn1 basename | sed 's/\.sops\.env$//')
    if [[ ${#EXISTING[@]} -gt 0 ]]; then
        CONTEXT=$(wizard choose \
            "Select a config (or create new)" \
            "${EXISTING[@]}" "Create new config") || exit 1
        if [[ "${CONTEXT}" == "Create new config" ]]; then
            CONTEXT=$(wizard ask "Enter the context name (SSH host alias)")
        fi
    else
        CONTEXT=$(wizard ask "Enter the context name (SSH host alias)")
    fi

    SOPS_AGE_KEY_FILE="${HOME}/.config/d.rymcg.tech/keys/sops/${CONTEXT}.age"
    mkdir -p "$(dirname "${SOPS_AGE_KEY_FILE}")"
    if [[ ! -f "${SOPS_AGE_KEY_FILE}" ]]; then
        echo "Key file not found: ${SOPS_AGE_KEY_FILE}"
        wizard confirm "Generate a new age keypair?" yes || exit 1
        age-keygen -o "${SOPS_AGE_KEY_FILE}"
    fi

    SOPS_AGE_RECIPIENTS=$(age-keygen -y "${SOPS_AGE_KEY_FILE}")
    export DOCKER_CONTEXT="${_CFG_TMP_CTX}"
    CONFIGURED=()

    if [[ -f "config/${CONTEXT}.sops.env" ]]; then
        echo ""
        echo "Loading existing config for ${CONTEXT}..."
        DECRYPTED=$(sops decrypt "config/${CONTEXT}.sops.env")
        SSH_HOST=$(awk -F= '/^SSH_HOST=/ {print $2; exit}' <<< "${DECRYPTED}")
        SSH_USER=$(awk -F= '/^SSH_USER=/ {print $2; exit}' <<< "${DECRYPTED}")
        SSH_PORT=$(awk -F= '/^SSH_PORT=/ {print $2; exit}' <<< "${DECRYPTED}")
        if ! ${D} restore-env --yes <<< "${DECRYPTED}"; then
            echo "WARNING: restore-env had errors (some projects may need reconfiguration)"
        fi
        for f in $(find "${_CFG_D_ROOT}" -name ".env_${_CFG_TMP_CTX}_*" -type f 2>/dev/null); do
            REL="${f#${_CFG_D_ROOT}/}"
            PROJECT="${REL%%/*}"
            INSTANCE="${REL##*.env_${_CFG_TMP_CTX}_}"
            ENTRY="${PROJECT}/${INSTANCE}"
            if ! printf '%s\n' "${CONFIGURED[@]}" 2>/dev/null | grep -qxF "${ENTRY}"; then
                CONFIGURED+=("${ENTRY}")
            fi
        done
    else
        SSH_CONFIG=$(ssh -G "${CONTEXT}" 2>/dev/null || true)
        _SSH_HOST=$(echo "${SSH_CONFIG}" | awk '/^hostname / {print $2}')
        _SSH_PORT=$(echo "${SSH_CONFIG}" | awk '/^port / {print $2; exit}')
        _SSH_USER=$(echo "${SSH_CONFIG}" | awk '/^user / {print $2}')
        SSH_HOST=$(wizard ask "Enter SSH host" "${_SSH_HOST}")
        SSH_PORT=$(wizard ask "Enter SSH port" "${_SSH_PORT:-22}")
        SSH_USER=$(wizard ask "Enter SSH user" "${_SSH_USER:-root}")
        echo ""
        echo "Running root config (context: ${CONTEXT})..."
        make --no-print-directory -C "${_CFG_D_ROOT}" check-dist-vars config-hook
        while true; do
            readarray -t PROJECTS < <(${D} list --raw)
            PROJECT=$(wizard choose \
                "Select a project to configure (or Done to finish)" \
                "Done" "${PROJECTS[@]}") || break
            [[ "${PROJECT}" == "Done" ]] && break
            INSTANCE=$(wizard ask "Enter the ${PROJECT} instance name" "default")
            make --no-print-directory -C "${_CFG_D_ROOT}/${PROJECT}" \
                check-dist-vars config-hook instance="${INSTANCE}" || true
            ENTRY="${PROJECT}/${INSTANCE}"
            if ! printf '%s\n' "${CONFIGURED[@]}" 2>/dev/null | grep -qxF "${ENTRY}"; then
                CONFIGURED+=("${ENTRY}")
            fi
        done
    fi

    while true; do
        _ROOT_DOMAIN=$(make --no-print-directory -C "${_CFG_D_ROOT}" dotenv_get var=ROOT_DOMAIN 2>/dev/null || echo "")
        REVIEW_OPTS=("Done" "Configure SSH (${SSH_HOST}:${SSH_PORT} as ${SSH_USER})" "Configure context (${_ROOT_DOMAIN:-unset})" "Add project")
        for c in "${CONFIGURED[@]}"; do
            REVIEW_OPTS+=("Reconfigure ${c}")
        done
        CHOICE=$(wizard choose \
            "Review configured instances (or Done to proceed)" \
            "${REVIEW_OPTS[@]}") || break
        [[ "${CHOICE}" == "Done" ]] && break
        if [[ "${CHOICE}" == Configure\ SSH* ]]; then
            SSH_HOST=$(wizard ask "Enter SSH host" "${SSH_HOST}")
            SSH_PORT=$(wizard ask "Enter SSH port" "${SSH_PORT}")
            SSH_USER=$(wizard ask "Enter SSH user" "${SSH_USER}")
        elif [[ "${CHOICE}" == Configure\ context* ]]; then
            ACTION=$(wizard choose \
                "Action for root config" "reconfig" "edit") || continue
            if [[ "${ACTION}" == "reconfig" ]]; then
                make --no-print-directory -C "${_CFG_D_ROOT}" config-hook || true
            elif [[ "${ACTION}" == "edit" ]]; then
                ${EDITOR:-vi} "${_CFG_D_ROOT}/.env_${_CFG_TMP_CTX}"
            fi
        elif [[ "${CHOICE}" == "Add project" ]]; then
            readarray -t PROJECTS < <(${D} list --raw)
            PROJECT=$(wizard choose \
                "Select a project to configure" \
                "${PROJECTS[@]}") || continue
            INSTANCE=$(wizard ask "Enter the ${PROJECT} instance name" "default")
            make --no-print-directory -C "${_CFG_D_ROOT}/${PROJECT}" \
                check-dist-vars config-hook instance="${INSTANCE}" || true
            ENTRY="${PROJECT}/${INSTANCE}"
            if ! printf '%s\n' "${CONFIGURED[@]}" 2>/dev/null | grep -qxF "${ENTRY}"; then
                CONFIGURED+=("${ENTRY}")
            fi
        else
            ENTRY="${CHOICE#Reconfigure }"
            R_PROJECT="${ENTRY%%/*}"
            R_INSTANCE="${ENTRY##*/}"
            ACTION=$(wizard choose \
                "Action for ${ENTRY}" "reconfig" "edit") || continue
            if [[ "${ACTION}" == "reconfig" ]]; then
                make --no-print-directory -C "${_CFG_D_ROOT}/${R_PROJECT}" \
                    check-dist-vars config-hook instance="${R_INSTANCE}" || true
            elif [[ "${ACTION}" == "edit" ]]; then
                make --no-print-directory -C "${_CFG_D_ROOT}/${R_PROJECT}" \
                    config-edit instance="${R_INSTANCE}" || true
            fi
        fi
    done

    PLAINTEXT=$(${D} export-env --context "${_CFG_TMP_CTX}" | sed '/^## SSH$/,/^## /{ /^## SSH$/d; /^SSH_/d; }')
    HEADER="## SSH"$'\n'"SSH_HOST=${SSH_HOST}"$'\n'"SSH_USER=${SSH_USER}"$'\n'"SSH_PORT=${SSH_PORT}"
    if [[ -n "${PLAINTEXT}" ]]; then
        COMBINED="${HEADER}"$'\n'$'\n'"${PLAINTEXT}"
    else
        COMBINED="${HEADER}"
    fi
    mkdir -p config
    echo "${COMBINED}" | sops encrypt \
        --input-type dotenv --output-type dotenv \
        --filename-override export.env \
        --age "${SOPS_AGE_RECIPIENTS}" /dev/stdin \
        > "config/${CONTEXT}.sops.env"
    echo ""
    echo "Config saved to config/${CONTEXT}.sops.env"
}

cmd_ci() {
    if [[ -z "${WOODPECKER_SERVER:-}" || -z "${WOODPECKER_TOKEN:-}" ]]; then
        echo "WOODPECKER_SERVER and WOODPECKER_TOKEN must be set."
        echo ""
        echo "Get your Personal Access Token from your Woodpecker instance:"
        echo "  https://woodpecker.example.com/user/cli-and-api"
        echo ""
        echo "Then export both variables:"
        echo "  export WOODPECKER_SERVER=https://woodpecker.example.com"
        echo "  export WOODPECKER_TOKEN=<your-token>"
        exit 1
    fi
    WP_SERVER="${WOODPECKER_SERVER%/}"
    WP_TOKEN="${WOODPECKER_TOKEN}"

    wp_api() {
        local method="$1" path="$2"; shift 2
        local http_code body
        body=$(curl -sS -w '\n%{http_code}' -X "${method}" \
            -H "Authorization: Bearer ${WP_TOKEN}" \
            -H "Content-Type: application/json" \
            "${WP_SERVER}/api${path}" "$@")
        http_code=$(echo "${body}" | tail -1)
        body=$(echo "${body}" | sed '$d')
        if [[ "${http_code}" -ge 400 ]]; then
            echo "${body}" >&2
            return 1
        fi
        echo "${body}"
    }

    REPO_FULL_NAME=$(git remote get-url origin \
        | sed -E 's|(\.git)$||; s|.*[:/]([^/]+/[^/]+)$|\1|')
    FORGE_HOST=$(git remote get-url origin \
        | sed -E 's|^[a-z+]+://||; s|^[^@]*@||; s|[:/].*||')
    REPO_OWNER="${REPO_FULL_NAME%%/*}"
    REPO_NAME="${REPO_FULL_NAME##*/}"
    echo "Repository: ${REPO_FULL_NAME}"
    echo ""

    # Check if the remote repo exists; if not, create it on Forgejo and push
    if ! git ls-remote origin &>/dev/null; then
        echo "Remote repository not found. Creating on Forgejo..."
        if [[ -z "${FORGEJO_TOKEN:-}" ]]; then
            echo ""
            echo "A Forgejo API token is required to create the repository."
            echo "Create one at: https://${FORGE_HOST}/user/settings/applications"
            echo "Required scopes: write:repository, write:user (or write:organization)"
            echo ""
            FORGEJO_TOKEN=$(wizard ask "Forgejo API token")
        fi
        FORGE_API="https://${FORGE_HOST}/api/v1"
        CREATE_BODY=$(jq -n --arg name "${REPO_NAME}" '{name: $name, private: true}')
        # Check if the owner is a Forgejo org or user
        ORG_CHECK=$(curl -sS -o /dev/null -w '%{http_code}' \
            -H "Authorization: token ${FORGEJO_TOKEN}" \
            "${FORGE_API}/orgs/${REPO_OWNER}")
        if [[ "${ORG_CHECK}" == "200" ]]; then
            CREATE_URL="${FORGE_API}/orgs/${REPO_OWNER}/repos"
        else
            CREATE_URL="${FORGE_API}/user/repos"
        fi
        CREATE_RESULT=$(curl -sS -w '\n%{http_code}' -X POST \
            -H "Authorization: token ${FORGEJO_TOKEN}" \
            -H "Content-Type: application/json" \
            "${CREATE_URL}" \
            -d "${CREATE_BODY}")
        CREATE_HTTP=$(echo "${CREATE_RESULT}" | tail -1)
        if [[ "${CREATE_HTTP}" -ge 400 ]]; then
            echo "Error: Could not create repository on Forgejo." >&2
            echo "${CREATE_RESULT}" | sed '$d' >&2
            exit 1
        fi
        echo "Created ${REPO_FULL_NAME} on Forgejo"
        echo "Pushing..."
        git push -u origin master
        echo ""
    elif [[ -z "$(git ls-remote origin 2>/dev/null)" ]]; then
        echo "Remote is empty. Pushing..."
        git push -u origin master
        echo ""
    fi

    LOOKUP=$(wp_api GET "/repos/lookup/${REPO_FULL_NAME}" 2>/dev/null) || true
    if [[ -n "${LOOKUP}" ]]; then
        REPO_ID=$(echo "${LOOKUP}" | jq -r '.id // empty' 2>/dev/null)
        ACTIVE=$(echo "${LOOKUP}" | jq -r '.active // false' 2>/dev/null)
    fi

    if [[ -z "${REPO_ID:-}" ]]; then
        echo "Repository not found on Woodpecker. Syncing repo list..."
        wp_api POST "/user/repos" > /dev/null 2>&1 || true
        # Retry lookup after sync
        LOOKUP=$(wp_api GET "/repos/lookup/${REPO_FULL_NAME}" 2>/dev/null) || true
        if [[ -n "${LOOKUP}" ]]; then
            REPO_ID=$(echo "${LOOKUP}" | jq -r '.id // empty' 2>/dev/null)
            ACTIVE=$(echo "${LOOKUP}" | jq -r '.active // false' 2>/dev/null)
        fi
    fi

    if [[ -z "${REPO_ID:-}" ]]; then
        echo "Searching forge for repository..."
        REPO_NAME="${REPO_FULL_NAME##*/}"
        FORGE_REPOS=$(wp_api GET "/user/repos?all=true&name=${REPO_NAME}" 2>/dev/null) || true
        FORGE_ID=$(echo "${FORGE_REPOS}" | jq -r \
            --arg full_name "${REPO_FULL_NAME}" \
            '.[] | select(.full_name == $full_name) | .forge_remote_id // empty' 2>/dev/null)
        if [[ -z "${FORGE_ID}" ]]; then
            echo "Error: Could not find repository on the forge. Make sure the repo exists and Woodpecker has access."
            exit 1
        fi
        echo "Activating repository..."
        RESULT=$(wp_api POST "/repos?forge_remote_id=${FORGE_ID}")
        REPO_ID=$(echo "${RESULT}" | jq -r '.id')
        echo "Repository activated (id: ${REPO_ID})"
    elif [[ "${ACTIVE}" != "true" ]]; then
        FORGE_ID=$(echo "${LOOKUP}" | jq -r '.forge_remote_id // empty')
        if [[ -z "${FORGE_ID}" ]]; then
            REPO_NAME="${REPO_FULL_NAME##*/}"
            FORGE_REPOS=$(wp_api GET "/user/repos?all=true&name=${REPO_NAME}" 2>/dev/null) || true
            FORGE_ID=$(echo "${FORGE_REPOS}" | jq -r \
                --arg full_name "${REPO_FULL_NAME}" \
                '.[] | select(.full_name == $full_name) | .forge_remote_id // empty' 2>/dev/null)
        fi
        echo "Activating repository..."
        RESULT=$(wp_api POST "/repos?forge_remote_id=${FORGE_ID}")
        REPO_ID=$(echo "${RESULT}" | jq -r '.id')
        echo "Repository activated (id: ${REPO_ID})"
    else
        echo "Repository already active (id: ${REPO_ID})"
    fi

    TRUSTED=$(echo "${LOOKUP:-${RESULT:-}}" | jq -r '.trusted // false' 2>/dev/null)
    if [[ "${TRUSTED}" != "true" ]]; then
        echo "Setting repository as trusted (required for privileged build steps)..."
        if wp_api PATCH "/repos/${REPO_ID}" -d '{"trusted":true}' > /dev/null 2>&1; then
            echo "Repository trusted."
        else
            echo "WARNING: Could not set trusted (requires Woodpecker admin token)."
            echo "  An admin can trust the repo via: Woodpecker UI > repo settings > Trusted"
        fi
    fi
    echo ""

    echo "Registry: ${FORGE_HOST}"

    readarray -t SOPS_FILES < <(ls config/*.sops.env 2>/dev/null)
    if [[ ${#SOPS_FILES[@]} -eq 0 ]]; then
        echo "No SOPS config found in config/. Run '$0 config' first."
        exit 1
    elif [[ ${#SOPS_FILES[@]} -eq 1 ]]; then
        SOPS_CONFIG="${SOPS_FILES[0]}"
    else
        SOPS_NAMES=()
        for f in "${SOPS_FILES[@]}"; do SOPS_NAMES+=("$(basename "$f")"); done
        SOPS_CHOICE=$(wizard choose "Select SOPS config for pipeline" "${SOPS_NAMES[@]}")
        SOPS_CONFIG="config/${SOPS_CHOICE}"
    fi
    echo "SOPS config: ${SOPS_CONFIG}"
    echo ""

    set_secret() {
        local name="$1" value="$2"
        local payload payload_events
        payload=$(jq -n --arg n "${name}" --arg v "${value}" '{name: $n, value: $v}')
        payload_events=$(jq -n --arg n "${name}" --arg v "${value}" '{name: $n, value: $v, events: ["push","manual","cron"]}')
        EXISTING=$(wp_api GET "/repos/${REPO_ID}/secrets/${name}" 2>/dev/null) &&
            wp_api PATCH "/repos/${REPO_ID}/secrets/${name}" \
                -d "${payload}" > /dev/null ||
            wp_api POST "/repos/${REPO_ID}/secrets" \
                -d "${payload_events}" > /dev/null
    }

    REQUIRED_SECRETS=("bao_addr:OpenBao server URL" "bao_role_id:AppRole role ID" "bao_secret_id:AppRole secret ID" "bao_age_key_path:KV path to AGE key")
    OPTIONAL_SECRETS=("bao_cacert:CA cert for OpenBao TLS" "bao_client_cert:mTLS client cert" "bao_client_key:mTLS client key" "bao_namespace:OpenBao namespace")

    echo "=== Required secrets ==="
    for entry in "${REQUIRED_SECRETS[@]}"; do
        name="${entry%%:*}"
        desc="${entry#*:}"
        CURRENT=$(wp_api GET "/repos/${REPO_ID}/secrets/${name}" 2>/dev/null | jq -r '.name // empty' 2>/dev/null) || true
        if [[ -n "${CURRENT}" ]]; then
            wizard confirm "${name} already set. Update ${desc}?" no || continue
        fi
        VALUE=$(wizard ask "Enter ${desc} (${name})")
        if [[ -n "${VALUE}" ]]; then
            set_secret "${name}" "${VALUE}"
            echo "  ${name}: set"
        fi
    done
    echo ""

    echo "=== Optional secrets ==="
    PEM_SECRETS="bao_cacert bao_client_cert bao_client_key"
    for entry in "${OPTIONAL_SECRETS[@]}"; do
        name="${entry%%:*}"
        desc="${entry#*:}"
        CURRENT=$(wp_api GET "/repos/${REPO_ID}/secrets/${name}" 2>/dev/null | jq -r '.name // empty' 2>/dev/null) || true
        if [[ -n "${CURRENT}" ]]; then
            wizard confirm "${name} already set. Update ${desc}?" no || continue
        fi
        wizard confirm "Set ${desc} (${name})?" no || continue
        if echo "${PEM_SECRETS}" | grep -qw "${name}"; then
            echo "Paste ${desc} PEM content, then press Ctrl-D on a new line:"
            VALUE=$(cat | base64 -w0)
        else
            VALUE=$(wizard ask "Enter ${desc} (${name})")
        fi
        if [[ -n "${VALUE}" ]]; then
            set_secret "${name}" "${VALUE}"
            echo "  ${name}: set"
        fi
    done
    echo ""

    echo "Woodpecker CI configured for ${REPO_FULL_NAME}"
}

cmd_view() {
    readarray -t FILES < <(ls config/*.sops.env 2>/dev/null)
    if [[ ${#FILES[@]} -eq 0 ]]; then
        echo "No config files found in config/"; exit 1
    fi
    NAMES=()
    for f in "${FILES[@]}"; do
        NAMES+=("$(basename "$f" .sops.env)")
    done
    CHOICE=$(wizard choose "Select a config to view" "${NAMES[@]}")
    sops decrypt "config/${CHOICE}.sops.env"
}

cmd_edit() {
    readarray -t FILES < <(ls config/*.sops.env 2>/dev/null)
    if [[ ${#FILES[@]} -eq 0 ]]; then
        echo "No config files found in config/"; exit 1
    fi
    NAMES=()
    for f in "${FILES[@]}"; do
        NAMES+=("$(basename "$f" .sops.env)")
    done
    CHOICE=$(wizard choose "Select a config to edit" "${NAMES[@]}")
    sops edit "config/${CHOICE}.sops.env"
}

case "${1:-}" in
    config) cmd_config ;;
    ci)     cmd_ci ;;
    view)   cmd_view ;;
    edit)   cmd_edit ;;
    *)      echo "Usage: $0 {config|ci|view|edit}"; exit 1 ;;
esac
