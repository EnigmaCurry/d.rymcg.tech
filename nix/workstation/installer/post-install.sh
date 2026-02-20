#!/usr/bin/env bash
## Post-install: copy archive data into the USB's nix store and create GC roots
## Usage: post-install.sh /mnt
## Must be run after nixos-install, while the USB is still mounted.
set -euo pipefail

MOUNT="${1:-}"
ARCHIVE_ROOT="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ARCHIVE_ROOT="${ARCHIVE_ROOT:-$FLAKE_DIR/_archive}"

if [[ -z "$MOUNT" ]]; then
    echo "Usage: $0 /mnt"
    echo "Copy archive data to a mounted NixOS workstation USB."
    echo ""
    echo "The USB root filesystem must be mounted at the given path."
    exit 1
fi

if [[ ! -d "$MOUNT/nix/store" ]]; then
    echo "Error: $MOUNT does not look like a NixOS root (no nix/store)." >&2
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

GCROOT_DIR="$MOUNT/nix/var/nix/gcroots"
mkdir -p "$GCROOT_DIR"

copy_to_store() {
    local name="$1"
    local source_dir="$2"
    local gcroot_name="$3"

    if [[ ! -d "$source_dir" ]]; then
        echo "Skipping $name: $source_dir not found"
        return
    fi

    # Check if directory has any content
    if [[ -z "$(ls -A "$source_dir" 2>/dev/null)" ]]; then
        echo "Skipping $name: $source_dir is empty"
        return
    fi

    echo "=== Adding $name to nix store ==="
    echo "Source: $source_dir"
    local size
    size=$(du -shL "$source_dir" | cut -f1)
    echo "Size: $size"

    # Add directly to the USB's nix store (avoids doubling storage on host)
    echo "Adding to USB nix store (this may take a while for large archives)..."
    local store_path
    store_path=$(nix store add --store "local?root=$MOUNT" --name "$gcroot_name" "$source_dir")
    echo "Store path: $store_path"

    # Create GC root on the USB
    ln -sfn "$store_path" "$GCROOT_DIR/$gcroot_name"
    echo "GC root: $GCROOT_DIR/$gcroot_name -> $store_path"
    echo ""
}

# Docker image archive
ARCHIVE_DIR="$ARCHIVE_ROOT/images/x86_64"
copy_to_store "Docker image archive" "$ARCHIVE_DIR" "workstation-usb-archive"

# ISOs
ISOS_DIR="$ARCHIVE_ROOT/isos"
copy_to_store "ISOs" "$ISOS_DIR" "workstation-usb-isos"

# Docker CE packages
DOCKER_PKG_DIR="$ARCHIVE_ROOT/docker-packages"
copy_to_store "Docker CE packages" "$DOCKER_PKG_DIR" "workstation-usb-docker-packages"

## Pre-download emacs packages for air-gapped use
echo "=== Pre-downloading emacs packages ==="
# Set up DNS in the chroot so straight.el can fetch packages
mkdir -p "$MOUNT/etc"
cp -L /etc/resolv.conf "$MOUNT/etc/resolv.conf" 2>/dev/null || true

# Bind-mount /dev, /proc, /sys for nixos-enter
mount --bind /dev "$MOUNT/dev" 2>/dev/null || true
mount --bind /proc "$MOUNT/proc" 2>/dev/null || true
mount --bind /sys "$MOUNT/sys" 2>/dev/null || true

# Pre-install Rust stable toolchain for air-gapped use
echo "=== Installing Rust stable toolchain ==="
chroot "$MOUNT" /run/current-system/sw/bin/su - user -c '
    rustup default stable
    rustup component add rust-src rust-analyzer clippy rustfmt
' || echo "Warning: Rust toolchain install failed (non-fatal)"

# Run emacs in batch mode as user to download all straight.el packages.
# init.el loads with my/machine-labels='() (no optional modules).
# We then call my/load-modules with all available labels to trigger downloads,
# and save the labels to custom.el so they persist on first boot.
echo "Running emacs in batch mode to download packages (this may take a while)..."
chroot "$MOUNT" /run/current-system/sw/bin/su - user -c '
    emacs --batch \
        -l ~/.emacs.d/init.el \
        --eval "(progn
            (my/load-modules (my/machine-labels-available))
            (customize-set-variable (quote my/machine-labels) (my/machine-labels-available))
            (customize-save-customized)
            (message \"Emacs packages downloaded and all machine labels enabled.\"))" \
        2>&1
' || echo "Warning: emacs package pre-download failed (non-fatal)"

# Clean up chroot mounts
umount "$MOUNT/sys" 2>/dev/null || true
umount "$MOUNT/proc" 2>/dev/null || true
umount "$MOUNT/dev" 2>/dev/null || true

echo "=== Post-install complete ==="
echo "Archive data has been copied to the USB's nix store."
echo "GC roots protect the data from garbage collection."
