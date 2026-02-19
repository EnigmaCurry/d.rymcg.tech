#!/usr/bin/env bash
## Post-install: copy archive data into the USB's nix store and create GC roots
## Usage: post-install.sh /mnt
## Must be run after nixos-install, while the USB is still mounted.
set -euo pipefail

MOUNT="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

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
    size=$(du -sh "$source_dir" | cut -f1)
    echo "Size: $size"

    # Add to the host nix store first
    echo "Adding to nix store (this may take a while for large archives)..."
    local store_path
    store_path=$(nix store add --name "$gcroot_name" "$source_dir")
    echo "Store path: $store_path"

    # Copy from host store to USB store
    echo "Copying to USB nix store..."
    nix copy --to "local?root=$MOUNT" "$store_path"

    # Create GC root on the USB
    ln -sfn "$store_path" "$GCROOT_DIR/$gcroot_name"
    echo "GC root: $GCROOT_DIR/$gcroot_name -> $store_path"
    echo ""
}

# Docker image archive
ARCHIVE_DIR="$FLAKE_DIR/_archive/images/x86_64"
copy_to_store "Docker image archive" "$ARCHIVE_DIR" "workstation-usb-archive"

# ISOs
ISOS_DIR="$FLAKE_DIR/_archive/isos"
copy_to_store "ISOs" "$ISOS_DIR" "workstation-usb-isos"

# Docker CE packages
DOCKER_PKG_DIR="$FLAKE_DIR/_archive/docker-packages"
copy_to_store "Docker CE packages" "$DOCKER_PKG_DIR" "workstation-usb-docker-packages"

echo "=== Post-install complete ==="
echo "Archive data has been copied to the USB's nix store."
echo "GC roots protect the data from garbage collection."
