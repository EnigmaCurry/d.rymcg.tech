#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"

usage() {
    echo "Usage: d.rymcg.tech container [OPTIONS] CONTEXT_OR_FILE"
    echo ""
    echo "Run an interactive d-rymcg-tech container with SOPS config support."
    echo ""
    echo "CONTEXT_OR_FILE can be a context name (e.g. 'myserver') which resolves"
    echo "to ~/.config/d.rymcg.tech/config/myserver.sops.env, or a direct file path."
    echo "On exit, you can review and save any configuration changes back"
    echo "to the encrypted file."
    echo ""
    echo "Options:"
    echo "  --image TAG      Container image (default: ghcr.io/enigmacurry/d-rymcg-tech:latest)"
    echo "  --docker         Use Docker instead of Podman"
    echo "  --age-key FILE   AGE key file (default: ~/.config/sops/age/keys.txt)"
    echo "  --ssh-key FILE   SSH key file (disables agent forwarding)"
    echo "  --no-save        Disable save-on-exit"
    echo "  --help           Show this help"
}

ENGINE=podman
IMAGE=ghcr.io/enigmacurry/d-rymcg-tech:latest
AGE_KEY_FILE="${HOME}/.config/sops/age/keys.txt"
SSH_KEY_FILE=""
SAVE_ON_EXIT=true
SOPS_CONFIG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --image) IMAGE="$2"; shift 2 ;;
        --docker) ENGINE=docker; shift ;;
        --age-key) AGE_KEY_FILE="$2"; shift 2 ;;
        --ssh-key) SSH_KEY_FILE="$2"; shift 2 ;;
        --no-save) SAVE_ON_EXIT=false; shift ;;
        --help) usage; exit 0 ;;
        -*)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
        *)
            if [[ -z "${SOPS_CONFIG}" ]]; then
                SOPS_CONFIG="$1"
            else
                echo "Error: unexpected argument: $1" >&2
                usage >&2
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ -z "${SOPS_CONFIG}" ]]; then
    echo "Error: CONTEXT_OR_FILE is required" >&2
    echo "" >&2
    usage >&2
    exit 1
fi

if ! command -v "${ENGINE}" &>/dev/null; then
    echo "Error: ${ENGINE} not found in PATH" >&2
    exit 1
fi

# If argument is a bare context name (no slashes, no .sops.env suffix),
# resolve to ~/.config/d.rymcg.tech/config/<context>.sops.env
if [[ "${SOPS_CONFIG}" != */* && "${SOPS_CONFIG}" != *.sops.env ]]; then
    SOPS_CONFIG="${HOME}/.config/d.rymcg.tech/config/${SOPS_CONFIG}.sops.env"
fi

# Resolve to absolute path
if [[ ! -f "${SOPS_CONFIG}" ]]; then
    echo "Error: SOPS config file not found: ${SOPS_CONFIG}" >&2
    echo "  Run 'd container-init' to create one." >&2
    exit 1
fi
SOPS_CONFIG="$(realpath "${SOPS_CONFIG}")"

if [[ ! -f "${AGE_KEY_FILE}" ]]; then
    echo "Error: AGE key file not found: ${AGE_KEY_FILE}" >&2
    echo "  Use --age-key to specify a different path" >&2
    exit 1
fi

CONTAINER_CONFIG_DIR=/home/user/git/vendor/enigmacurry/d.rymcg.tech/config
SOPS_BASENAME="$(basename "${SOPS_CONFIG}")"

RUN_ARGS=(
    run --rm -it
    -e "SOPS_CONFIG_FILE=${CONTAINER_CONFIG_DIR}/${SOPS_BASENAME}"
    -v "${SOPS_CONFIG}:${CONTAINER_CONFIG_DIR}/${SOPS_BASENAME}"
    -v "${AGE_KEY_FILE}:/home/user/.config/sops/age/keys.txt:ro"
    -e "SOPS_AGE_KEY_FILE=/home/user/.config/sops/age/keys.txt"
)

if [[ "${SAVE_ON_EXIT}" == true ]]; then
    RUN_ARGS+=(-e "SOPS_SAVE_ON_EXIT=true")
fi

# SSH: forward agent or mount key file
if [[ -n "${SSH_KEY_FILE}" ]]; then
    SSH_KEY_FILE="$(realpath "${SSH_KEY_FILE}")"
    if [[ ! -f "${SSH_KEY_FILE}" ]]; then
        echo "Error: SSH key file not found: ${SSH_KEY_FILE}" >&2
        exit 1
    fi
    RUN_ARGS+=(-v "${SSH_KEY_FILE}:/run/secrets/ssh/id_ed25519:ro")
elif [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
    RUN_ARGS+=(
        -v "${SSH_AUTH_SOCK}:/run/ssh-agent.sock:ro"
        -e "SSH_AUTH_SOCK=/run/ssh-agent.sock"
    )
fi

RUN_ARGS+=("${IMAGE}")

echo "## Starting d-rymcg-tech container (${ENGINE})" >&2
echo "## Config: ${SOPS_CONFIG}" >&2
echo "## Image:  ${IMAGE}" >&2
exec "${ENGINE}" "${RUN_ARGS[@]}"
