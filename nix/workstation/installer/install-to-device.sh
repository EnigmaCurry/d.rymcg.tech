#!/usr/bin/env bash
## Install NixOS workstation directly to a USB device
## Usage: install-to-device.sh /dev/sdX
set -euo pipefail

DEVICE="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

if [[ -z "$DEVICE" ]]; then
    echo "Usage: $0 /dev/sdX"
    echo "Install NixOS workstation to a USB device."
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
trap 'umount -R "$MOUNT" 2>/dev/null || true; rmdir "$MOUNT" 2>/dev/null || true' EXIT

echo "=== Building NixOS system closure ==="
SYSTEM_PATH=$(nix build "${FLAKE_DIR}#nixosConfigurations.workstation.config.system.build.toplevel" --no-link --print-out-paths)
echo "System closure: $SYSTEM_PATH"

echo "=== Partitioning $DEVICE ==="
# Wipe existing partition table
sgdisk --zap-all "$DEVICE"
# Create ESP (512MB) and root partition (rest)
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:ESP "$DEVICE"
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
mount "$ESP" "$MOUNT/boot"

echo "=== Installing NixOS ==="
nixos-install --system "$SYSTEM_PATH" --root "$MOUNT" --no-root-password --no-channel-copy

echo "=== Running post-install ==="
if [[ -x "$SCRIPT_DIR/post-install.sh" ]]; then
    "$SCRIPT_DIR/post-install.sh" "$MOUNT"
else
    echo "Note: Run workstation-usb-post-install $MOUNT to copy archive data."
fi

echo ""
echo "=== Installation complete ==="
echo "You can now boot from $DEVICE."
echo "Default passwords: admin/admin, user/user (change on first boot)."
echo "The root partition will auto-expand on first boot."
