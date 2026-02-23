#!/usr/bin/env bash
## Install NixOS workstation directly to a USB device
## Usage: install-to-device.sh [OPTIONS] /dev/sdX
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BIN="${FLAKE_DIR}/_scripts"
ROOT_DIR="$FLAKE_DIR"
source "${BIN}/funcs.sh"
source "${BIN}/workstation-build-lib.sh"

DEVICE=""
BASE_ONLY=""
ARCHIVE_SOURCE="${FLAKE_DIR}/_archive"
MANIFEST_FILE=""

usage() {
    echo "Usage: $0 [OPTIONS] /dev/sdX"
    echo ""
    echo "Install NixOS workstation directly to a USB device."
    echo "Must be run as root."
    echo ""
    echo "Options:"
    echo "  --base-only    Install OS only, without archive data"
    echo "  -h, --help     Show this help"
    echo ""
    echo "Default password matches the username (change on first boot)."
    echo "The root partition auto-expands to fill the USB on first boot."
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --base-only)
            BASE_ONLY=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
        *)
            DEVICE="$1"
            shift
            ;;
    esac
done

if [[ -z "$DEVICE" ]]; then
    usage
    exit 1
fi

if [[ ! -b "$DEVICE" ]]; then
    echo "Error: $DEVICE is not a block device." >&2
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

# Archive selection (before device confirmation so user can cancel early)
if [[ -z "$BASE_ONLY" ]]; then
    workstation_archive_preflight
    workstation_archive_select
fi

# Safety check
echo "WARNING: This will ERASE ALL DATA on $DEVICE"
echo ""
lsblk "$DEVICE"
echo ""
read -p "Type YES to continue: " confirm
if [[ "$confirm" != "YES" ]]; then
    echo "Aborted."
    exit 1
fi

MOUNT=$(mktemp -d)
cleanup() {
    set +e
    umount -R "$MOUNT" 2>/dev/null || true
    rmdir "$MOUNT" 2>/dev/null || true
    if [[ -n "${MANIFEST_FILE:-}" ]] && [[ "$MANIFEST_FILE" == /tmp/* ]]; then
        rm -f "$MANIFEST_FILE" 2>/dev/null
    fi
}
trap cleanup EXIT

echo ""
workstation_create_bare_repos

echo ""
echo "=== Building NixOS system closure ==="
SYSTEM_PATH=$(workstation_nix_build "nixosConfigurations.workstation.config.system.build.toplevel")
echo "System closure: $SYSTEM_PATH"

NIXOS_INSTALL=$(workstation_nix_build "nixosConfigurations.workstation.config.system.build.nixos-install")/bin/nixos-install
if [[ ! -x "$NIXOS_INSTALL" ]]; then
    echo "Error: nixos-install not found at $NIXOS_INSTALL" >&2
    exit 1
fi
echo "nixos-install: $NIXOS_INSTALL"

echo "=== Partitioning $DEVICE ==="
# Wipe existing partition table
sgdisk --zap-all "$DEVICE"
# Create ESP (1GB) and root partition (rest)
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:ESP "$DEVICE"
sgdisk -n 2:0:0 -t 2:8300 -c 2:nixos "$DEVICE"
partprobe "$DEVICE" || true
sleep 2

# Determine partition names (handle nvme vs sd naming)
if [[ "$DEVICE" =~ [0-9]$ ]]; then
    ESP="${DEVICE}p1"
    ROOT="${DEVICE}p2"
else
    ESP="${DEVICE}1"
    ROOT="${DEVICE}2"
fi

echo "=== Formatting ==="
mkfs.fat -F32 -n ESP "$ESP"
mkfs.ext4 -L nixos -F "$ROOT"

echo "=== Mounting ==="
mount "$ROOT" "$MOUNT"
mkdir -p "$MOUNT/boot"
mount -o umask=0077 "$ESP" "$MOUNT/boot"

echo "=== Installing NixOS ==="
"$NIXOS_INSTALL" --system "$SYSTEM_PATH" --root "$MOUNT" --no-root-password --no-channel-copy

sed -i 's/^title .*/title d.rymcg.tech NixOS Installer/' "$MOUNT/boot/loader/entries/"*.conf

echo ""
echo "=== Archiving flake inputs for offline nixos-rebuild ==="
nix flake archive --to "local?root=$MOUNT" "$ROOT_DIR"
mkdir -p "$MOUNT/root/.cache/nix"
cp -a /root/.cache/nix/fetcher-cache-v*.sqlite* "$MOUNT/root/.cache/nix/" 2>/dev/null || true
echo "Flake inputs archived"

echo "=== Running post-install ==="
if [[ -x "$SCRIPT_DIR/post-install.sh" ]]; then
    if [[ -z "$BASE_ONLY" ]]; then
        "$SCRIPT_DIR/post-install.sh" "$MOUNT" "${MANIFEST_FILE:-}"
    else
        "$SCRIPT_DIR/post-install.sh" "$MOUNT" --chroot-only
    fi
else
    echo "Note: Run workstation-usb-post-install $MOUNT to copy archive data."
fi

echo ""
echo "=== Installation complete ==="
echo "You can now boot from $DEVICE."
echo "Default password matches the username (change on first boot)."
echo "The root partition will auto-expand on first boot."
