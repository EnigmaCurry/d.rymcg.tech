#!/usr/bin/env bash
## Configure (or unconfigure) a remote Docker host as a client of registry-cache.
## Supports no-auth and HTTP Basic Auth (when passwords.json exists).
##
## All registries (including Docker Hub) are configured via containerd
## hosts.toml files. The containerd image store ("containerd-snapshotter")
## is enabled in daemon.json so that Docker uses containerd for pulls,
## which reads the hosts.toml configuration.
##
## Usage:
##   ENV_FILE=.env_foo bash configure-docker.sh [configure|unconfigure]
##
## Requires ENV_FILE in the environment (set by the Makefile target).
## Default mode is "configure".
set -euo pipefail

MODE="${1:-configure}"
if [[ "${MODE}" != "configure" && "${MODE}" != "unconfigure" ]]; then
    echo "Usage: $0 [configure|unconfigure]" >&2
    exit 1
fi

BIN=$(dirname "${BASH_SOURCE[0]}")/../_scripts
source "${BIN}/funcs.sh"

# Profile -> upstream registry mapping
# Docker Hub uses "docker.io" as the containerd host directory name
# (not "registry-1.docker.io") because that's how containerd resolves it.
declare -A PROFILE_UPSTREAM=(
    [dockerhub]="docker.io"
    [ghcr]="ghcr.io"
    [quay]="quay.io"
    [gcr]="gcr.io"
    [k8s]="registry.k8s.io"
    [gitlab]="registry.gitlab.com"
    [ecr]="public.ecr.aws"
    [lscr]="lscr.io"
    [codeberg]="codeberg.org"
)

# Profile -> the actual upstream server URL (for hosts.toml "server" field)
declare -A PROFILE_SERVER=(
    [dockerhub]="https://registry-1.docker.io"
    [ghcr]="https://ghcr.io"
    [quay]="https://quay.io"
    [gcr]="https://gcr.io"
    [k8s]="https://registry.k8s.io"
    [gitlab]="https://registry.gitlab.com"
    [ecr]="https://public.ecr.aws"
    [lscr]="https://lscr.io"
    [codeberg]="https://codeberg.org"
)

# Profile -> env var name for the cache hostname
declare -A PROFILE_HOST_VAR=(
    [dockerhub]="REGISTRY_CACHE_DOCKERHUB_TRAEFIK_HOST"
    [ghcr]="REGISTRY_CACHE_GHCR_TRAEFIK_HOST"
    [quay]="REGISTRY_CACHE_QUAY_TRAEFIK_HOST"
    [gcr]="REGISTRY_CACHE_GCR_TRAEFIK_HOST"
    [k8s]="REGISTRY_CACHE_K8S_TRAEFIK_HOST"
    [gitlab]="REGISTRY_CACHE_GITLAB_TRAEFIK_HOST"
    [ecr]="REGISTRY_CACHE_ECR_TRAEFIK_HOST"
    [lscr]="REGISTRY_CACHE_LSCR_TRAEFIK_HOST"
    [codeberg]="REGISTRY_CACHE_CODEBERG_TRAEFIK_HOST"
)

# Collect enabled profiles and their cache hostnames
declare -A CACHE_HOSTS
HAS_AUTH=false
AUTH_USERNAME=""
AUTH_PASSWORD=""

read_config() {
    check_var ENV_FILE
    if [[ ! -f "${ENV_FILE}" ]]; then
        fault "Missing .env file: ${ENV_FILE} — run 'make config' first."
    fi

    local profiles
    profiles="$(dotenv_get DOCKER_COMPOSE_PROFILES)"
    if [[ -z "${profiles}" ]]; then
        fault "DOCKER_COMPOSE_PROFILES is empty in ${ENV_FILE} — run 'make config' first."
    fi

    local profile
    for profile in ${profiles//,/ }; do
        if [[ -z "${PROFILE_HOST_VAR[$profile]+x}" ]]; then
            continue
        fi
        local host_var="${PROFILE_HOST_VAR[$profile]}"
        local host
        host="$(dotenv_get "${host_var}")"
        CACHE_HOSTS[$profile]="${host}"
    done

    if [[ ${#CACHE_HOSTS[@]} -eq 0 ]]; then
        fault "No registry cache profiles found in ${ENV_FILE}."
    fi

    # Check if HTTP Basic Auth is enabled
    local http_auth
    http_auth="$(${BIN}/dotenv -f "${ENV_FILE}" get REGISTRY_CACHE_HTTP_AUTH 2>/dev/null || true)"
    if [[ -n "${http_auth}" ]]; then
        # Auth is enabled — look for credentials in passwords.json
        local context_instance
        context_instance="$(basename "${ENV_FILE}" | sed 's/^\.env_//')"
        if [[ -f passwords.json ]]; then
            AUTH_USERNAME="$(jq -r --arg key "${context_instance}" '.[$key][0].username // empty' passwords.json)"
            AUTH_PASSWORD="$(jq -r --arg key "${context_instance}" '.[$key][0].password // empty' passwords.json)"
            if [[ -n "${AUTH_USERNAME}" && -n "${AUTH_PASSWORD}" ]]; then
                HAS_AUTH=true
                echo "HTTP Basic Auth: credentials found in passwords.json (user: ${AUTH_USERNAME})"
            else
                fault "HTTP Basic Auth is enabled but no credentials found for \"${context_instance}\" in passwords.json."
            fi
        else
            fault "HTTP Basic Auth is enabled but passwords.json not found. Run 'make config' and export passwords."
        fi
    fi
}

choose_target_context() {
    local current_context
    current_context="$(docker context show)"

    # Build list of contexts excluding 'default' (local socket, not SSH)
    local -a contexts
    readarray -t contexts < <(docker context list -q | grep -v '^default$')

    if [[ ${#contexts[@]} -eq 0 ]]; then
        fault "No remote Docker contexts found. Create one with 'docker context create'."
    fi

    echo ""
    echo "Current Docker context (registry-cache server): ${current_context}"
    echo "Choose the Docker client host to ${MODE}:"
    echo ""

    TARGET_CONTEXT="$(wizard choose "Select the Docker context to ${MODE}" "${contexts[@]}")"
    if [[ -z "${TARGET_CONTEXT}" ]]; then
        fault "No context selected."
    fi

    SSH_HOST=$(docker context inspect "${TARGET_CONTEXT}" --format '{{.Endpoints.docker.Host}}' | sed 's|ssh://||')
    check_var SSH_HOST
}

preflight_local() {
    echo "=== Pre-flight checks (local) ==="
    if ! command -v jq >/dev/null 2>&1; then
        fault "jq is required locally but not found. Install it and retry."
    fi
    echo "  jq: OK"
    echo "  .env: ${ENV_FILE}"
    echo "  SSH host: ${SSH_HOST}"
    echo ""
}

preflight_remote() {
    echo "=== Pre-flight checks (remote: ${SSH_HOST}) ==="

    if ! ssh "${SSH_HOST}" true 2>/dev/null; then
        fault "Cannot connect to ${SSH_HOST} via SSH."
    fi
    echo "  SSH connectivity: OK"

    if ! ssh "${SSH_HOST}" sudo true 2>/dev/null; then
        fault "sudo does not work on ${SSH_HOST}."
    fi
    echo "  sudo: OK"

    # Check for read-only /etc (e.g. NixOS)
    if ! ssh "${SSH_HOST}" 'sudo test -w /etc' 2>/dev/null; then
        echo ""
        echo "  ERROR: /etc on ${SSH_HOST} is read-only."
        echo "  This host appears to use an immutable filesystem (e.g. NixOS)."
        echo "  Docker and containerd must be configured through your OS"
        echo "  configuration system (e.g. configuration.nix) instead."
        echo ""
        fault "/etc is not writable on ${SSH_HOST}."
    fi
    echo "  /etc writable: OK"

    if ! ssh "${SSH_HOST}" command -v docker >/dev/null 2>&1; then
        fault "Docker not found on ${SSH_HOST}."
    fi
    echo "  docker: OK"

    if ! ssh "${SSH_HOST}" command -v systemctl >/dev/null 2>&1; then
        fault "systemctl not found on ${SSH_HOST} (needed to restart Docker)."
    fi
    echo "  systemctl: OK"

    echo ""
}

## ── configure ────────────────────────────────────────────────────

configure_daemon_json() {
    echo "--- daemon.json (containerd image store) ---"

    local TMP_EXIST TMP_MERGED
    TMP_EXIST="$(mktemp)"
    TMP_MERGED="$(mktemp)"
    trap "rm -f '${TMP_EXIST}' '${TMP_MERGED}'" RETURN

    # Read existing daemon.json (or empty object)
    if ! ssh "${SSH_HOST}" 'test -s /etc/docker/daemon.json && sudo cat /etc/docker/daemon.json || echo "{}"' >"${TMP_EXIST}"; then
        fault "Failed to read /etc/docker/daemon.json from ${SSH_HOST}."
    fi

    # Enable containerd-snapshotter and remove registry-mirrors (incompatible with auth)
    jq '. + {"features": (.features // {} | . + {"containerd-snapshotter": true})} | del(."registry-mirrors")' \
        "${TMP_EXIST}" >"${TMP_MERGED}"

    local REMOTE_TMP="/tmp/daemon.json.${RANDOM}.${RANDOM}"
    if ! scp -q "${TMP_MERGED}" "${SSH_HOST}:${REMOTE_TMP}"; then
        fault "Failed to upload daemon.json to ${SSH_HOST}."
    fi

    ssh "${SSH_HOST}" "sudo install -d -m 0755 /etc/docker \
        && sudo install -b -m 0644 '${REMOTE_TMP}' /etc/docker/daemon.json \
        && rm -f '${REMOTE_TMP}'"

    echo "  Enabled containerd-snapshotter in /etc/docker/daemon.json"
}

configure_hosts_toml() {
    local profile="$1"
    local cache_host="${CACHE_HOSTS[$profile]}"
    local upstream="${PROFILE_UPSTREAM[$profile]}"
    local server="${PROFILE_SERVER[$profile]}"
    local cache_url="https://${cache_host}"
    local remote_dir="/etc/containerd/certs.d/${upstream}"

    echo "--- ${upstream} (${cache_host}) ---"

    local TMP_TOML
    TMP_TOML="$(mktemp)"
    trap "rm -f '${TMP_TOML}'" RETURN

    cat >"${TMP_TOML}" <<EOF
server = "${server}"

[host."${cache_url}"]
  capabilities = ["pull", "resolve"]
EOF

    if ${HAS_AUTH}; then
        local b64
        b64="$(printf '%s:%s' "${AUTH_USERNAME}" "${AUTH_PASSWORD}" | base64 -w0)"
        cat >>"${TMP_TOML}" <<EOF
  [host."${cache_url}".header]
    Authorization = ["Basic ${b64}"]
EOF
    fi

    local REMOTE_TMP="/tmp/hosts.toml.${RANDOM}.${RANDOM}"
    if ! scp -q "${TMP_TOML}" "${SSH_HOST}:${REMOTE_TMP}"; then
        fault "Failed to upload hosts.toml for ${upstream} to ${SSH_HOST}."
    fi

    ssh "${SSH_HOST}" "sudo install -d -m 0755 '${remote_dir}' \
        && sudo install -b -m 0644 '${REMOTE_TMP}' '${remote_dir}/hosts.toml' \
        && rm -f '${REMOTE_TMP}'"

    echo "  Installed ${remote_dir}/hosts.toml"
}

do_configure() {
    echo "The following will be configured on ${SSH_HOST}:"
    echo "  - /etc/docker/daemon.json (enable containerd image store)"
    for profile in "${!CACHE_HOSTS[@]}"; do
        echo "  - /etc/containerd/certs.d/${PROFILE_UPSTREAM[$profile]}/hosts.toml (-> ${CACHE_HOSTS[$profile]})"
    done
    echo "  - restart docker"
    echo ""
    confirm yes "Configure ${SSH_HOST} as a registry cache client" "?" || exit 0

    echo ""
    echo "=== Configuring ${SSH_HOST} ==="
    echo ""

    configure_daemon_json

    for profile in "${!CACHE_HOSTS[@]}"; do
        configure_hosts_toml "${profile}"
    done

    echo ""
    echo "=== Restarting Docker ==="
    ssh "${SSH_HOST}" "sudo systemctl restart docker"
    echo "  Docker restarted."

    echo ""
    echo "Done. ${SSH_HOST} is now configured to use registry caches."
}

## ── unconfigure ──────────────────────────────────────────────────

unconfigure_daemon_json() {
    echo "--- daemon.json (remove containerd image store) ---"

    local TMP_EXIST TMP_CLEANED
    TMP_EXIST="$(mktemp)"
    TMP_CLEANED="$(mktemp)"
    trap "rm -f '${TMP_EXIST}' '${TMP_CLEANED}'" RETURN

    if ! ssh "${SSH_HOST}" 'test -s /etc/docker/daemon.json && sudo cat /etc/docker/daemon.json || echo "{}"' >"${TMP_EXIST}"; then
        fault "Failed to read /etc/docker/daemon.json from ${SSH_HOST}."
    fi

    # Remove containerd-snapshotter feature and registry-mirrors
    jq 'del(.features."containerd-snapshotter") | del(."registry-mirrors")
        | if .features == {} then del(.features) else . end' \
        "${TMP_EXIST}" >"${TMP_CLEANED}"

    local REMOTE_TMP="/tmp/daemon.json.${RANDOM}.${RANDOM}"
    if ! scp -q "${TMP_CLEANED}" "${SSH_HOST}:${REMOTE_TMP}"; then
        fault "Failed to upload daemon.json to ${SSH_HOST}."
    fi

    ssh "${SSH_HOST}" "sudo install -b -m 0644 '${REMOTE_TMP}' /etc/docker/daemon.json \
        && rm -f '${REMOTE_TMP}'"

    echo "  Removed containerd-snapshotter from /etc/docker/daemon.json"
}

do_unconfigure() {
    echo "The following will be removed from ${SSH_HOST}:"
    echo "  - containerd-snapshotter from /etc/docker/daemon.json"
    for profile in "${!CACHE_HOSTS[@]}"; do
        echo "  - /etc/containerd/certs.d/${PROFILE_UPSTREAM[$profile]}/"
    done
    echo "  - restart docker"
    echo ""
    confirm yes "Remove registry cache client configuration from ${SSH_HOST}" "?" || exit 0

    echo ""
    echo "=== Unconfiguring ${SSH_HOST} ==="
    echo ""

    unconfigure_daemon_json

    for profile in "${!CACHE_HOSTS[@]}"; do
        local upstream="${PROFILE_UPSTREAM[$profile]}"
        echo "--- ${upstream} ---"
        ssh "${SSH_HOST}" "sudo rm -rf '/etc/containerd/certs.d/${upstream}'"
        echo "  Removed /etc/containerd/certs.d/${upstream}"
    done

    echo ""
    echo "=== Restarting Docker ==="
    ssh "${SSH_HOST}" "sudo systemctl restart docker"
    echo "  Docker restarted."

    echo ""
    echo "Done. Registry cache client configuration removed from ${SSH_HOST}."
}

## ── main ─────────────────────────────────────────────────────────

main() {
    read_config
    choose_target_context

    preflight_local
    preflight_remote

    if [[ "${MODE}" == "configure" ]]; then
        do_configure
    else
        do_unconfigure
    fi
}

main
