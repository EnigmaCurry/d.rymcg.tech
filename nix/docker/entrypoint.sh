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
cat > ~/.ssh/config <<EOF
Host ${DOCKER_CONTEXT}
    HostName ${SSH_HOST}
    User ${SSH_USER}
    Port ${SSH_PORT}
    StrictHostKeyChecking no
    IdentityFile ${KEY_DIR}/id_ed25519
EOF
chmod 600 ~/.ssh/config

## Step 3: Create and activate Docker context
docker context create "${DOCKER_CONTEXT}" \
    --docker "host=ssh://${SSH_USER}@${SSH_HOST}:${SSH_PORT}" &>/dev/null || true
docker context use "${DOCKER_CONTEXT}" &>/dev/null

## Step 4: Create root .env_{DOCKER_CONTEXT} via config-dist, then overlay env vars
cd "${ROOT_DIR}"
d.rymcg.tech make - config-dist &>/dev/null

while IFS= read -r key; do
    if [[ -n "${!key+set}" ]]; then
        d.rymcg.tech make - reconfigure "var=${key}=${!key}" &>/dev/null
    fi
done < <(d.rymcg.tech script dotenv -f .env-dist parse | cut -d= -f1)

## Step 5: Distribute prefixed env vars to project .env files
declare -A prefix_to_dir
for project_dir in */; do
    project_name="${project_dir%/}"
    env_dist_file="${project_dir}.env-dist"
    [[ -f "${env_dist_file}" ]] || continue
    prefix=$("${BIN}/parse-env-meta.sh" "${env_dist_file}" PREFIX 2>/dev/null) || continue
    [[ -n "${prefix}" ]] || continue
    prefix_to_dir["${prefix}"]="${project_name}"
done

# Collect which projects need config-dist based on matching env vars
declare -A projects_to_configure
for var in $(compgen -v); do
    for prefix in "${!prefix_to_dir[@]}"; do
        if [[ "${var}" == "${prefix}_"* ]]; then
            projects_to_configure["${prefix}"]=1
            break
        fi
    done
done

# For each matched project, run config-dist then reconfigure matching vars
for prefix in "${!projects_to_configure[@]}"; do
    project_name="${prefix_to_dir[${prefix}]}"
    d.rymcg.tech make "${project_name}" config-dist &>/dev/null
    for var in $(compgen -v); do
        if [[ "${var}" == "${prefix}_"* ]]; then
            d.rymcg.tech make "${project_name}" reconfigure "var=${var}=${!var}" &>/dev/null
        fi
    done
done

## Step 6: Ensure explicitly requested projects have env files
if [[ -n "${_PROJECTS:-}" ]]; then
    IFS=, read -ra _requested_projects <<< "${_PROJECTS}"
    for project_name in "${_requested_projects[@]}"; do
        env_file="${project_name}/.env_${DOCKER_CONTEXT}_default"
        if [[ ! -f "${env_file}" ]]; then
            d.rymcg.tech make "${project_name}" config-dist &>/dev/null
        fi
    done
fi

## Step 7: Exec the command
exec "$@"
