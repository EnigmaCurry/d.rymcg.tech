#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"

usage() {
    echo "Usage: d.rymcg.tech build-container [OPTIONS]"
    echo ""
    echo "Build the d-rymcg-tech container image from the current repo."
    echo ""
    echo "Options:"
    echo "  --podman       Use Podman instead of Docker"
    echo "  --tag TAG      Image tag (default: localhost/d-rymcg-tech:latest)"
    echo "  --arch ARCH    Target platform (e.g. linux/amd64). Can be specified multiple times"
    echo "  --push         Push image after building"
    echo "  --help         Show this help"
}

ENGINE=docker
TAG=localhost/d-rymcg-tech:latest
PUSH=false
ARCHS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --podman) ENGINE=podman; shift ;;
        --tag) TAG="$2"; shift 2 ;;
        --arch) ARCHS+=("$2"); shift 2 ;;
        --push) PUSH=true; shift ;;
        --help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
done

if ! command -v "${ENGINE}" &>/dev/null; then
    echo "Error: ${ENGINE} not found in PATH" >&2
    exit 1
fi

PLATFORM_FLAGS=()
if [[ ${#ARCHS[@]} -gt 0 ]]; then
    PLATFORM=$(IFS=,; echo "${ARCHS[*]}")
    PLATFORM_FLAGS=(--platform "${PLATFORM}")
fi

echo "## Building ${TAG} with ${ENGINE}${PLATFORM:+ (${PLATFORM})}" >&2
cd "${ROOT_DIR}"

if [[ ${#ARCHS[@]} -gt 1 || "${PUSH}" == true && ${#ARCHS[@]} -gt 0 ]]; then
    # Multi-arch or push with platform requires buildx
    PUSH_FLAG=()
    [[ "${PUSH}" == true ]] && PUSH_FLAG=(--push)
    ${ENGINE} buildx build -f _container/Dockerfile \
        "${PLATFORM_FLAGS[@]}" \
        -t "${TAG}" \
        "${PUSH_FLAG[@]}" \
        .
else
    git archive HEAD | ${ENGINE} build -f _container/Dockerfile \
        "${PLATFORM_FLAGS[@]}" \
        -t "${TAG}" -
    if [[ "${PUSH}" == true ]]; then
        echo "## Pushing ${TAG}" >&2
        ${ENGINE} push "${TAG}"
    fi
fi
