#!/usr/bin/env bash
## Configure a remote Docker host as a client of registry-cache.
## Supports no-auth and HTTP Basic Auth (when passwords.json exists).
##
## Requires ENV_FILE in the environment (set by the Makefile target).
set -euo pipefail

BIN=$(dirname "${BASH_SOURCE[0]}")/../_scripts
source "${BIN}/funcs.sh"

# Profile -> upstream registry mapping
declare -A PROFILE_UPSTREAM=(
    [dockerhub]="registry-1.docker.io"
    [ghcr]="ghcr.io"
    [quay]="quay.io"
    [gcr]="gcr.io"
    [k8s]="registry.k8s.io"
    [gitlab]="registry.gitlab.com"
    [ecr]="public.ecr.aws"
    [lscr]="lscr.io"
    [codeberg]="codeberg.org"
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
HAS_DOCKERHUB=false
HAS_CONTAINERD=false
CONTAINERD_OK=false
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
        if [[ "${profile}" == "dockerhub" ]]; then
            HAS_DOCKERHUB=true
        else
            HAS_CONTAINERD=true
        fi
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

get_ssh_host() {
    SSH_HOST=$(docker context inspect --format '{{.Endpoints.docker.Host}}' | sed 's|ssh://||')
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

    if ! ssh "${SSH_HOST}" command -v install >/dev/null 2>&1; then
        fault "'install' command not found on ${SSH_HOST}."
    fi
    echo "  install: OK"

    # Check for read-only /etc (e.g. NixOS)
    if ! ssh "${SSH_HOST}" 'sudo test -w /etc' 2>/dev/null; then
        echo ""
        echo "  ERROR: /etc on ${SSH_HOST} is read-only."
        echo "  This host appears to use an immutable filesystem (e.g. NixOS)."
        echo "  Docker and containerd must be configured through your OS"
        echo "  configuration system (e.g. configuration.nix) instead."
        echo ""
        echo "  For NixOS, add to your configuration.nix:"
        echo ""
        if ${HAS_DOCKERHUB}; then
            echo "    virtualisation.docker.daemon.settings.registry-mirrors ="
            echo "      [ \"https://${CACHE_HOSTS[dockerhub]}\" ];"
            echo ""
        fi
        if ${HAS_CONTAINERD}; then
            echo "  For containerd registries, see:"
            echo "    https://docs.docker.com/engine/containerd/#hosts-directory"
            echo ""
        fi
        fault "/etc is not writable on ${SSH_HOST}."
    fi
    echo "  /etc writable: OK"

    if ${HAS_DOCKERHUB}; then
        if ! ssh "${SSH_HOST}" command -v docker >/dev/null 2>&1; then
            fault "Docker not found on ${SSH_HOST} (needed for dockerhub mirror)."
        fi
        echo "  docker: OK"

        if ! ssh "${SSH_HOST}" command -v systemctl >/dev/null 2>&1; then
            fault "systemctl not found on ${SSH_HOST} (needed to restart Docker)."
        fi
        echo "  systemctl: OK"
    fi

    if ${HAS_CONTAINERD}; then
        if ssh "${SSH_HOST}" systemctl is-active containerd >/dev/null 2>&1; then
            CONTAINERD_OK=true
            echo "  containerd: OK (active)"
        else
            echo "  containerd: WARNING — not running as a systemd service."
            echo "    hosts.toml files will still be written, but containerd"
            echo "    must be configured to use /etc/containerd/certs.d/ for"
            echo "    them to take effect."
        fi
    fi

    echo ""
}

configure_dockerhub() {
    local cache_host="${CACHE_HOSTS[dockerhub]}"
    local mirror_url="https://${cache_host}"

    echo "--- Docker Hub (${cache_host}) ---"

    local TMP_EXIST TMP_OVERLAY TMP_MERGED
    TMP_EXIST="$(mktemp)"
    TMP_OVERLAY="$(mktemp)"
    TMP_MERGED="$(mktemp)"
    trap "rm -f '${TMP_EXIST}' '${TMP_OVERLAY}' '${TMP_MERGED}'" RETURN

    # Read existing daemon.json (or empty object)
    if ! ssh "${SSH_HOST}" 'test -s /etc/docker/daemon.json && sudo cat /etc/docker/daemon.json || echo "{}"' >"${TMP_EXIST}"; then
        fault "Failed to read /etc/docker/daemon.json from ${SSH_HOST}."
    fi

    # Build overlay with registry-mirrors
    jq -n --arg mirror "${mirror_url}" \
        '{ "registry-mirrors": [$mirror] }' >"${TMP_OVERLAY}"

    # Merge: existing + overlay. For registry-mirrors, replace the array
    # rather than appending, so the cache is the only mirror.
    jq -s '.[0] * .[1]' "${TMP_EXIST}" "${TMP_OVERLAY}" >"${TMP_MERGED}"

    # Upload and install
    local REMOTE_TMP="/tmp/daemon.json.${RANDOM}.${RANDOM}"
    if ! scp -q "${TMP_MERGED}" "${SSH_HOST}:${REMOTE_TMP}"; then
        fault "Failed to upload daemon.json to ${SSH_HOST}."
    fi

    ssh "${SSH_HOST}" "sudo install -d -m 0755 /etc/docker \
        && sudo install -b -m 0644 '${REMOTE_TMP}' /etc/docker/daemon.json \
        && rm -f '${REMOTE_TMP}'"

    echo "  Installed /etc/docker/daemon.json"

    if ${HAS_AUTH}; then
        echo "  Logging in to ${cache_host} ..."
        ssh "${SSH_HOST}" "docker login '${cache_host}' -u '${AUTH_USERNAME}' --password-stdin" \
            <<< "${AUTH_PASSWORD}"
        echo "  docker login: OK"
    fi
}

configure_containerd_host() {
    local profile="$1"
    local cache_host="${CACHE_HOSTS[$profile]}"
    local upstream="${PROFILE_UPSTREAM[$profile]}"
    local cache_url="https://${cache_host}"
    local remote_dir="/etc/containerd/certs.d/${upstream}"

    echo "--- ${upstream} (${cache_host}) ---"

    local TMP_TOML
    TMP_TOML="$(mktemp)"
    trap "rm -f '${TMP_TOML}'" RETURN

    cat >"${TMP_TOML}" <<EOF
server = "https://${upstream}"

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

restart_services() {
    echo ""
    echo "=== Restarting services ==="

    if ${HAS_DOCKERHUB}; then
        echo "  Restarting Docker ..."
        ssh "${SSH_HOST}" "sudo systemctl restart docker"
        echo "  Docker restarted."
    fi

    if ${HAS_CONTAINERD} && ${CONTAINERD_OK}; then
        echo "  Restarting containerd ..."
        ssh "${SSH_HOST}" "sudo systemctl restart containerd"
        echo "  containerd restarted."
    fi
}

main() {
    read_config
    get_ssh_host

    preflight_local
    preflight_remote

    echo "The following will be configured on ${SSH_HOST}:"
    if ${HAS_DOCKERHUB}; then
        echo "  - /etc/docker/daemon.json (registry-mirrors -> ${CACHE_HOSTS[dockerhub]})"
        if ${HAS_AUTH}; then
            echo "  - docker login ${CACHE_HOSTS[dockerhub]}"
        fi
    fi
    for profile in "${!CACHE_HOSTS[@]}"; do
        if [[ "${profile}" != "dockerhub" ]]; then
            echo "  - /etc/containerd/certs.d/${PROFILE_UPSTREAM[$profile]}/hosts.toml (-> ${CACHE_HOSTS[$profile]})"
        fi
    done
    if ${HAS_DOCKERHUB}; then
        echo "  - restart docker"
    fi
    if ${HAS_CONTAINERD} && ${CONTAINERD_OK}; then
        echo "  - restart containerd"
    fi
    echo ""
    confirm yes "Configure ${SSH_HOST} as a registry cache client" "?" || exit 0

    echo ""
    echo "=== Configuring ${SSH_HOST} ==="
    echo ""

    if ${HAS_DOCKERHUB}; then
        configure_dockerhub
    fi

    for profile in "${!CACHE_HOSTS[@]}"; do
        if [[ "${profile}" != "dockerhub" ]]; then
            configure_containerd_host "${profile}"
        fi
    done

    restart_services

    echo ""
    echo "Done. ${SSH_HOST} is now configured to use registry caches."
}

main
