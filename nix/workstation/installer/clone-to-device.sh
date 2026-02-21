#!/usr/bin/env bash
## Clone the booted workstation USB to another device
## Usage: clone-to-device.sh [OPTIONS] /dev/sdX
## Must be run as root on a booted workstation USB.
## No build or network access required.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DEVICE=""
BASE_ONLY=""

usage() {
    echo "Usage: $0 [OPTIONS] /dev/sdX"
    echo ""
    echo "Clone this booted workstation USB to another device."
    echo "Reuses the running system closure — no build or network needed."
    echo "Must be run as root."
    echo ""
    echo "Options:"
    echo "  --base-only    Install OS only, without archive data"
    echo "  -h, --help     Show this help"
    echo ""
    echo "Default passwords: admin/admin, user/user (change on first boot)."
    echo "The root partition auto-expands to fill the device on first boot."
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

# Resolve the running system closure
SYSTEM_PATH=$(readlink -f /run/current-system)
if [[ ! -d "$SYSTEM_PATH" ]]; then
    echo "Error: /run/current-system does not resolve to a valid path." >&2
    echo "This script must be run on a booted NixOS workstation USB." >&2
    exit 1
fi
echo "System closure: $SYSTEM_PATH"

# Find nixos-install
NIXOS_INSTALL=$(command -v nixos-install 2>/dev/null || true)
if [[ -z "$NIXOS_INSTALL" ]]; then
    echo "Error: nixos-install not found in PATH." >&2
    echo "Ensure nixos-install-tools is in systemPackages." >&2
    exit 1
fi
echo "nixos-install: $NIXOS_INSTALL"

# Safety check
echo ""
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
}
trap cleanup EXIT

echo ""
echo "=== Partitioning $DEVICE ==="
sgdisk --zap-all "$DEVICE"
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

# Copy archive GC roots from the booted USB to the target
if [[ -z "$BASE_ONLY" ]]; then
    GCROOT_DIR="/nix/var/nix/gcroots"
    TARGET_GCROOT="$MOUNT/nix/var/nix/gcroots"
    mkdir -p "$TARGET_GCROOT"

    echo ""
    echo "=== Copying archive data ==="

    copy_count=0
    for root in "$GCROOT_DIR"/workstation-usb-*; do
        [[ -L "$root" ]] || continue
        name=$(basename "$root")
        store_path=$(readlink "$root")
        if [[ ! -e "$store_path" ]]; then
            echo "  Skipping $name: store path does not exist"
            continue
        fi
        size=$(du -shL "$store_path" | cut -f1)
        echo "  Copying $name ($size)..."
        target_store=$(nix store add --store "local?root=$MOUNT" --name "$name" "$store_path")
        ln -sfn "$target_store" "$TARGET_GCROOT/$name"
        echo "    -> $target_store"
        copy_count=$((copy_count + 1))
    done

    if [[ $copy_count -eq 0 ]]; then
        echo "  No archive GC roots found to copy."
    else
        echo "  Copied $copy_count archive items."
    fi
fi

echo ""
echo "=== Running post-install chroot tasks ==="
if [[ -x "$SCRIPT_DIR/post-install.sh" ]]; then
    "$SCRIPT_DIR/post-install.sh" "$MOUNT" --chroot-only
else
    echo "Warning: post-install.sh not found, skipping chroot tasks."
fi

echo ""
echo "=== Clone complete ==="
echo "You can now boot from $DEVICE."
echo "Default passwords: admin/admin, user/user (change on first boot)."
echo "The root partition will auto-expand on first boot."
