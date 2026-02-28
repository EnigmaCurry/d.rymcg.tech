#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR=/home/user/git/vendor/enigmacurry/d.rymcg.tech
BIN="${ROOT_DIR}/_scripts"

## Step 0: Set up PATH so the d.rymcg.tech CLI works
export PATH="${ROOT_DIR}/_scripts/user:${PATH}"

## Step 1: Validate required env vars
if [[ -z "${DOCKER_CONTEXT}" ]]; then
    echo "ERROR: DOCKER_CONTEXT is required" >&2
    exit 1
fi
if [[ -z "${SSH_HOST}" ]]; then
    echo "ERROR: SSH_HOST is required" >&2
    exit 1
fi
SSH_USER="${SSH_USER:-root}"
SSH_PORT="${SSH_PORT:-22}"

## Step 2: Set up SSH key and config
KEY_DIR=/run/secrets/ssh
mkdir -p "${KEY_DIR}" ~/.ssh && chmod 700 "${KEY_DIR}" ~/.ssh
if [[ ! -f "${KEY_DIR}/id_ed25519" ]]; then
    ssh-keygen -t ed25519 -N "" -f "${KEY_DIR}/id_ed25519" -q
fi
if [[ "${SSH_KEY_SCAN}" != "false" ]]; then
    if ! ssh-keyscan -p "${SSH_PORT}" "${SSH_HOST}" >> "${KEY_DIR}/known_hosts" 2>/dev/null; then
        echo "ERROR: ssh-keyscan failed for ${SSH_HOST}:${SSH_PORT} (set SSH_KEY_SCAN=false to skip)" >&2
        exit 1
    fi
fi
cat > ~/.ssh/config <<EOF
Host ${DOCKER_CONTEXT}
    HostName ${SSH_HOST}
    User ${SSH_USER}
    Port ${SSH_PORT}
    IdentityFile ${KEY_DIR}/id_ed25519
    UserKnownHostsFile ${KEY_DIR}/known_hosts
EOF
chmod 600 ~/.ssh/config

## Step 3: Create and activate Docker context
docker context create "${DOCKER_CONTEXT}" \
    --docker "host=ssh://${SSH_USER}@${SSH_HOST}:${SSH_PORT}" &>/dev/null || true
docker context use "${DOCKER_CONTEXT}" &>/dev/null

## Step 4: Create root .env and distribute env vars via restore-env
cd "${ROOT_DIR}"
cp -n .env-dist ".env_${DOCKER_CONTEXT}"
env | d.rymcg.tech restore-env

## Step 5: Ensure explicitly requested projects have env files
if [[ -n "${_PROJECTS:-}" ]]; then
    IFS=, read -ra _requested_projects <<< "${_PROJECTS}"
    for project_name in "${_requested_projects[@]}"; do
        env_file="${project_name}/.env_${DOCKER_CONTEXT}_default"
        if [[ ! -f "${env_file}" ]]; then
            cp "${project_name}/.env-dist" "${env_file}"
        fi
    done
fi

## Step 6: Exec the command
exec "$@"
