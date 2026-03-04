#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"

usage() {
    echo "Usage: d.rymcg.tech container-init [OPTIONS] [CONTEXT_NAME]"
    echo ""
    echo "Bootstrap a new d-rymcg-tech deployment config."
    echo ""
    echo "Generates an AGE encryption key (if needed) and creates a SOPS-encrypted"
    echo "config file for the given context. Only requires Podman (or Docker)."
    echo ""
    echo "Options:"
    echo "  --image TAG    Container image (default: ghcr.io/enigmacurry/d-rymcg-tech:latest)"
    echo "  --build        Build the container image first (using container-build)"
    echo "  --docker       Use Docker instead of Podman"
    echo "  --help         Show this help"
}

ENGINE=podman
IMAGE=ghcr.io/enigmacurry/d-rymcg-tech:latest
BUILD=false
CONTEXT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --image) IMAGE="$2"; shift 2 ;;
        --build) BUILD=true; shift ;;
        --docker) ENGINE=docker; shift ;;
        --help) usage; exit 0 ;;
        -*)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
        *)
            if [[ -z "${CONTEXT}" ]]; then
                CONTEXT="$1"
            else
                echo "Error: unexpected argument: $1" >&2
                usage >&2
                exit 1
            fi
            shift
            ;;
    esac
done

## Check engine
if ! command -v "${ENGINE}" &>/dev/null; then
    echo "Error: ${ENGINE} not found in PATH" >&2
    echo "Install ${ENGINE} first, or use --docker to use Docker instead." >&2
    exit 1
fi

## Build the image if requested
if [[ "${BUILD}" == true ]]; then
    BUILD_ARGS=(--tag "${IMAGE}")
    if [[ "${ENGINE}" == podman ]]; then
        BUILD_ARGS+=(--podman)
    fi
    "${ROOT_DIR}/_container/container-build.sh" "${BUILD_ARGS[@]}"
fi

## Run a command inside the container, bypassing the entrypoint
container_run() {
    "${ENGINE}" run --rm --entrypoint "" "$@"
}

## Run script-wizard inside the container interactively
## Mount /dev/tty so the TUI renders on the host terminal,
## while stdout (the answer) is captured normally by $()
wizard() {
    container_run -i \
        -e "TERM=${TERM:-xterm}" \
        -v /dev/tty:/dev/tty \
        "${IMAGE}" \
        sh -c 'script-wizard "$@" </dev/tty 2>/dev/tty' -- "$@"
}

## Context name
if [[ -z "${CONTEXT}" ]]; then
    CONTEXT=$(wizard ask "Enter the context name (SSH host alias)")
fi

## Check for existing config
CONFIG_DIR="${HOME}/.config/d.rymcg.tech/config"
if [[ -f "${CONFIG_DIR}/${CONTEXT}.sops.env" ]]; then
    echo "Config already exists: ${CONFIG_DIR}/${CONTEXT}.sops.env"
    echo ""
    echo "To modify it interactively, run:"
    echo "  d container ${CONTEXT}"
    exit 0
fi

## Ensure AGE key (one per context)
AGE_KEY_DIR="${HOME}/.config/d.rymcg.tech/keys/sops"
AGE_KEY_FILE="${AGE_KEY_DIR}/${CONTEXT}.key"
if [[ ! -f "${AGE_KEY_FILE}" ]]; then
    echo "No AGE key found for context '${CONTEXT}'"
    echo "Generating a new AGE keypair..."
    mkdir -p "${AGE_KEY_DIR}"
    container_run "${IMAGE}" age-keygen > "${AGE_KEY_FILE}"
    chmod 600 "${AGE_KEY_FILE}"
    echo "AGE key created: ${AGE_KEY_FILE}"
else
    echo "Using existing AGE key: ${AGE_KEY_FILE}"
fi

## Extract public key from the comment in the key file
PUBKEY=$(grep -o 'age1[a-z0-9]*' "${AGE_KEY_FILE}" | head -1)
echo "AGE public key: ${PUBKEY}"
echo ""

## SSH details — pre-fill from ssh config if available
echo "[debug] Running ssh -G ${CONTEXT} ..." >&2
SSH_CONFIG=$(ssh -G "${CONTEXT}" 2>/dev/null || true)
echo "[debug] ssh -G done" >&2
_SSH_HOST=$(echo "${SSH_CONFIG}" | awk '/^hostname / {print $2}')
_SSH_PORT=$(echo "${SSH_CONFIG}" | awk '/^port / {print $2; exit}')
_SSH_USER=$(echo "${SSH_CONFIG}" | awk '/^user / {print $2}')
echo "[debug] Defaults: host=${_SSH_HOST} port=${_SSH_PORT} user=${_SSH_USER}" >&2

echo "[debug] About to run wizard ask for SSH_HOST ..." >&2
SSH_HOST=$(wizard ask "Enter SSH host" "${_SSH_HOST}")
echo "[debug] SSH_HOST=${SSH_HOST}" >&2
SSH_PORT=$(wizard ask "Enter SSH port" "${_SSH_PORT:-22}")
echo "[debug] SSH_PORT=${SSH_PORT}" >&2
SSH_USER=$(wizard ask "Enter SSH user" "${_SSH_USER:-root}")
echo "[debug] SSH_USER=${SSH_USER}" >&2

## Create SOPS config
PLAINTEXT="## SSH
SSH_HOST=${SSH_HOST}
SSH_USER=${SSH_USER}
SSH_PORT=${SSH_PORT}"

mkdir -p "${CONFIG_DIR}"
echo "${PLAINTEXT}" | container_run -i \
    "${IMAGE}" \
    sops encrypt \
        --input-type dotenv --output-type dotenv \
        --filename-override export.env \
        --age "${PUBKEY}" /dev/stdin \
    > "${CONFIG_DIR}/${CONTEXT}.sops.env"

echo ""
echo "Config saved to ${CONFIG_DIR}/${CONTEXT}.sops.env"
echo ""
echo "Next steps:"
echo "  d container ${CONTEXT}"
