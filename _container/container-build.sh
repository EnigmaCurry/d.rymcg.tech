#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"

usage() {
    echo "Usage: d.rymcg.tech container-build [OPTIONS]"
    echo ""
    echo "Build the d-rymcg-tech container image from the current repo."
    echo ""
    echo "Options:"
    echo "  --docker       Use Docker instead of Podman"
    echo "  --image TAG    Image tag (default: localhost/d-rymcg-tech:latest)"
    echo "  --arch ARCH    Target platform (e.g. linux/amd64). Can be specified multiple times"
    echo "  --extra-packages PKGS  Additional Alpine packages to install (space-separated, quoted)"
    echo "  --editor CMD   Set EDITOR in the image (default: nano)"
    echo "  --install-doctl    Install doctl (DigitalOcean CLI)"
    echo "  --install-aws     Install aws CLI"
    echo "  --install-gh       Install gh (GitHub CLI)"
    echo "  --install-rclone   Install rclone"
    echo "  --push         Push image after building"
    echo "  --help         Show this help"
}

ENGINE=podman
TAG=localhost/d-rymcg-tech:latest
PUSH=false
ARCHS=()
EXTRA_PACKAGES=""
EDITOR_CMD=""
INSTALL_DOCTL=false
INSTALL_AWS=false
INSTALL_GH=false
INSTALL_RCLONE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --docker) ENGINE=docker; shift ;;
        --image|--tag) TAG="$2"; shift 2 ;;
        --arch) ARCHS+=("$2"); shift 2 ;;
        --extra-packages) EXTRA_PACKAGES="$2"; shift 2 ;;
        --editor) EDITOR_CMD="$2"; shift 2 ;;
        --install-doctl) INSTALL_DOCTL=true; shift ;;
        --install-aws) INSTALL_AWS=true; shift ;;
        --install-gh) INSTALL_GH=true; shift ;;
        --install-rclone) INSTALL_RCLONE=true; shift ;;
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

BUILD_ARGS=()
if [[ -n "${EXTRA_PACKAGES}" ]]; then
    BUILD_ARGS+=(--build-arg "EXTRA_PACKAGES=${EXTRA_PACKAGES}")
fi
if [[ -n "${EDITOR_CMD}" ]]; then
    BUILD_ARGS+=(--build-arg "EDITOR=${EDITOR_CMD}")
fi

GIT_SHA=$(git -C "${ROOT_DIR}" rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_ARGS+=(--build-arg "GIT_SHA=${GIT_SHA}")
BUILD_ARGS+=(--build-arg "INSTALL_DOCTL=${INSTALL_DOCTL}")
BUILD_ARGS+=(--build-arg "INSTALL_AWS=${INSTALL_AWS}")
BUILD_ARGS+=(--build-arg "INSTALL_GH=${INSTALL_GH}")
BUILD_ARGS+=(--build-arg "INSTALL_RCLONE=${INSTALL_RCLONE}")

cd "${ROOT_DIR}"

# Warn if tracked files have uncommitted changes (git archive only includes committed files)
if [[ -n "$(git diff --name-only HEAD 2>/dev/null)" ]]; then
    echo "WARNING: There are uncommitted changes that will NOT be included in the build" >&2
    echo "         (git archive HEAD only packages committed files)" >&2
    git diff --stat HEAD >&2
    if [[ -t 0 ]]; then
        read -rp "Continue anyway? [y/N] " answer
        if [[ "${answer}" != [yY]* ]]; then
            echo "Aborted." >&2
            exit 1
        fi
    else
        echo "Aborted (run interactively to confirm, or commit changes first)." >&2
        exit 1
    fi
fi

echo "## Building ${TAG} with ${ENGINE}${PLATFORM:+ (${PLATFORM})}" >&2

if [[ ${#ARCHS[@]} -gt 1 || "${PUSH}" == true && ${#ARCHS[@]} -gt 0 ]]; then
    # Multi-arch or push with platform requires buildx
    PUSH_FLAG=()
    [[ "${PUSH}" == true ]] && PUSH_FLAG=(--push)
    ${ENGINE} buildx build -f _container/Dockerfile \
        "${PLATFORM_FLAGS[@]}" \
        "${BUILD_ARGS[@]}" \
        -t "${TAG}" \
        "${PUSH_FLAG[@]}" \
        .
else
    git archive HEAD | ${ENGINE} build -f _container/Dockerfile \
        "${PLATFORM_FLAGS[@]}" \
        "${BUILD_ARGS[@]}" \
        -t "${TAG}" -
    if [[ "${PUSH}" == true ]]; then
        echo "## Pushing ${TAG}" >&2
        ${ENGINE} push "${TAG}"
    fi
fi
