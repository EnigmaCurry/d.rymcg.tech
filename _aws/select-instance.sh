#!/bin/bash
## Outputs the instance name, either from $1 or by prompting with script-wizard.
## Usage: instance=$(./select-instance.sh "$instance" "$DOCKER_CONTEXT" "$BIN" [--create])
## --create adds a "(create new)" option to the wizard.
set -eo pipefail
INSTANCE="$1"
DOCKER_CONTEXT="$2"
BIN="$3"
CREATE="$4"

if [[ -n "${INSTANCE}" ]]; then
    echo "${INSTANCE}"
    exit 0
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -n "${DRT_ENV_DIR:-}" ]]; then
    _SEARCH_DIR="${DRT_ENV_DIR}/$(basename "${DIR}")"
else
    _SEARCH_DIR="${DIR}"
fi
readarray -t INSTANCES < <(for f in "${_SEARCH_DIR}"/.env_${DOCKER_CONTEXT}_*; do
    [[ -f "$f" ]] || continue
    INST="$(basename "$f")"
    INST="${INST#.env_${DOCKER_CONTEXT}_}"
    [[ -n "${INST}" ]] && echo "${INST}"
done)

if [[ "${CREATE}" == "--create" ]]; then
    INSTANCES+=("(create new)")
fi

if [[ ${#INSTANCES[@]} -eq 0 || -z "${INSTANCES[0]}" ]]; then
    echo "## No instances configured. Run: make config instance=NAME" >&2
    exit 1
fi

INST=$("${BIN}/script-wizard" choose "Select an instance" "${INSTANCES[@]}")
if [[ "${INST}" == "(create new)" ]]; then
    read -e -p "Enter new instance name: " INST
    [[ -n "${INST}" ]] || (echo "## Error: instance name required." >&2 && exit 1)
fi
echo "${INST}"
