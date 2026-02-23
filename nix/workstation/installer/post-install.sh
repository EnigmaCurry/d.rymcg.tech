#!/usr/bin/env bash
## Post-install: copy archive data and pre-download packages for air-gapped use
## Usage: post-install.sh /mnt [MANIFEST|ARCHIVE_ROOT|--chroot-only]
## Must be run after nixos-install, while the USB is still mounted.
set -euo pipefail

MOUNT="${1:-}"
CHROOT_ONLY=""
ARCHIVE_ROOT=""
MANIFEST_MODE=""
IMAGE_PROJECTS=""
COMFYUI_FILES=""
INCLUDE_ISOS=true
INCLUDE_DOCKER_PACKAGES=true

if [[ "${2:-}" == "--chroot-only" ]] || [[ "${3:-}" == "--chroot-only" ]]; then
    CHROOT_ONLY=1
elif [[ -f "${2:-}" ]]; then
    # Manifest file with archive selection
    MANIFEST_MODE=1
    source "${2}"
elif [[ -n "${2:-}" ]]; then
    # Legacy: archive root directory
    ARCHIVE_ROOT="${2:-}"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ARCHIVE_ROOT="${ARCHIVE_ROOT:-$FLAKE_DIR/_archive}"

if [[ -z "$MOUNT" ]]; then
    echo "Usage: $0 /mnt [MANIFEST|ARCHIVE_ROOT|--chroot-only]"
    echo "Copy archive data to a mounted NixOS workstation USB and"
    echo "pre-download packages (emacs, Rust) for air-gapped use."
    echo ""
    echo "The USB root filesystem must be mounted at the given path."
    echo ""
    echo "Args:"
    echo "  MANIFEST       Path to selection manifest (from workstation-usb-image)"
    echo "  ARCHIVE_ROOT   Path to archive directory (default: _archive/)"
    echo "  --chroot-only  Skip archive copying, only run chroot tasks"
    exit 1
fi

if [[ ! -d "$MOUNT/nix/store" ]]; then
    echo "Error: $MOUNT does not look like a NixOS root (no nix/store)." >&2
    exit 1
fi

# Discover the normal user account (first UID >= 1000, < 65534)
TARGET_USER=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1; exit}' "$MOUNT/etc/passwd")
if [[ -z "$TARGET_USER" ]]; then
    echo "Error: no normal user found in $MOUNT/etc/passwd" >&2
    exit 1
fi
echo "Target user: $TARGET_USER"

if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

## Copy archive data to the USB's nix store (skipped with --chroot-only)
if [[ -z "$CHROOT_ONLY" ]]; then
    GCROOT_DIR="$MOUNT/nix/var/nix/gcroots"
    mkdir -p "$GCROOT_DIR"

    add_to_store() {
        local source_path="$1"
        local store_name="$2"
        local gcroot_name="$3"

        if [[ -L "$source_path" ]]; then
            source_path=$(realpath "$source_path")
        fi

        if [[ ! -e "$source_path" ]]; then
            echo "  Skipping $store_name: not found"
            return
        fi

        if [[ -d "$source_path" ]] && [[ -z "$(ls -A "$source_path" 2>/dev/null)" ]]; then
            echo "  Skipping $store_name: empty"
            return
        fi

        local size
        size=$(du -shL "$source_path" | cut -f1)
        echo "  Adding $store_name ($size)..."
        local store_path
        store_path=$(nix store add --store "local?root=$MOUNT" --name "$gcroot_name" "$source_path")
        ln -sfn "$store_path" "$GCROOT_DIR/$gcroot_name"
        echo "    -> $store_path"
    }

    ARCHIVE_IMG_DIR="$ARCHIVE_ROOT/images/x86_64"

    if [[ -n "$MANIFEST_MODE" ]]; then
        # Manifest mode: add only selected categories
        if [[ -n "$IMAGE_PROJECTS" ]] || [[ -n "$COMFYUI_FILES" ]]; then
            echo "=== Adding Docker images to nix store ==="
            for proj in $IMAGE_PROJECTS; do
                add_to_store "$ARCHIVE_IMG_DIR/$proj" "$proj" "workstation-usb-image-$proj"
            done
            for f in $COMFYUI_FILES; do
                add_to_store "$ARCHIVE_IMG_DIR/comfyui/$f" "comfyui/$f" "workstation-usb-comfyui-$f"
            done
            if [[ -f "$ARCHIVE_IMG_DIR/manifest.json" ]]; then
                add_to_store "$ARCHIVE_IMG_DIR/manifest.json" "manifest.json" "workstation-usb-image-manifest"
            fi
            echo ""
        else
            echo "=== Docker images: none selected, skipping ==="
            echo ""
        fi

        if $INCLUDE_ISOS; then
            echo "=== Adding ISOs to nix store ==="
            add_to_store "$ARCHIVE_ROOT/isos" "ISOs" "workstation-usb-isos"
            echo ""
        fi

        if $INCLUDE_DOCKER_PACKAGES; then
            echo "=== Adding Docker CE packages to nix store ==="
            add_to_store "$ARCHIVE_ROOT/docker-packages" "Docker CE packages" "workstation-usb-docker-packages"
            echo ""
        fi
    else
        # Legacy mode: add entire archive directories
        echo "=== Adding Docker image archive to nix store ==="
        add_to_store "$ARCHIVE_IMG_DIR" "Docker image archive" "workstation-usb-archive"
        echo ""
        echo "=== Adding ISOs to nix store ==="
        add_to_store "$ARCHIVE_ROOT/isos" "ISOs" "workstation-usb-isos"
        echo ""
        echo "=== Adding Docker CE packages to nix store ==="
        add_to_store "$ARCHIVE_ROOT/docker-packages" "Docker CE packages" "workstation-usb-docker-packages"
        echo ""
    fi
fi

## Set up chroot environment for pre-download tasks
# Set up DNS so straight.el can fetch packages
mkdir -p "$MOUNT/etc"
cp -L /etc/resolv.conf "$MOUNT/etc/resolv.conf" 2>/dev/null || true

# Bind-mount /dev, /proc, /sys for chroot
mount --bind /dev "$MOUNT/dev" 2>/dev/null || true
mount --bind /proc "$MOUNT/proc" 2>/dev/null || true
mount --bind /sys "$MOUNT/sys" 2>/dev/null || true

# Create per-user profile directory so home-manager's installPackages step
# can create the nix profile on first boot. Without this, home.packages
# (including fonts) silently fail to install.
_uid=$(grep "^${TARGET_USER}:" "$MOUNT/etc/passwd" | cut -d: -f3)
_gid=$(grep "^${TARGET_USER}:" "$MOUNT/etc/passwd" | cut -d: -f4)
mkdir -p "$MOUNT/nix/var/nix/profiles/per-user/$TARGET_USER"
chown "$_uid:$_gid" "$MOUNT/nix/var/nix/profiles/per-user/$TARGET_USER"

# Create home-manager gcroots directory so the activation script's
# nix-store --realise --add-root can succeed on first boot.
mkdir -p "$MOUNT/home/$TARGET_USER/.local/state/home-manager/gcroots"
chown -R "$_uid:$_gid" "$MOUNT/home/$TARGET_USER/.local"

# /run/current-system doesn't persist after nixos-install (/run is tmpfs at boot).
# Find the system closure and create the symlink so chroot commands work.
SYSTEM_STORE=$(find "$MOUNT/nix/store" -maxdepth 1 -name '*-nixos-system-*' -type d 2>/dev/null | head -1)
if [[ -n "$SYSTEM_STORE" ]]; then
    SYSTEM_PATH="${SYSTEM_STORE#$MOUNT}"  # chroot-relative path
    mkdir -p "$MOUNT/run"
    ln -sfn "$SYSTEM_PATH" "$MOUNT/run/current-system"
    echo "Set up /run/current-system -> $SYSTEM_PATH"
else
    echo "Warning: NixOS system closure not found, chroot tasks may fail"
fi

# Home-manager activation only runs on first boot (as a systemd service),
# so ~/.emacs.d/ doesn't exist yet in the chroot after nixos-install.
# Create it from the home-manager generation so emacs pre-download works.
echo "=== Setting up home-manager symlinks ==="
USER_HOME="$MOUNT/home/$TARGET_USER"
HM_GEN=$(find "$MOUNT/nix/store" -maxdepth 1 -name '*-home-manager-generation' -type d 2>/dev/null | head -1)
if [[ -n "$HM_GEN" ]] && [[ -L "$HM_GEN/home-files" ]]; then
    HM_HOME_FILES=$(readlink "$HM_GEN/home-files")
    # HM_HOME_FILES is a chroot-relative absolute path (e.g. /nix/store/xxx-home-files)
    # Prepend $MOUNT to access it from the host
    if [[ -d "$MOUNT$HM_HOME_FILES/.emacs.d" ]]; then
        mkdir -p "$USER_HOME/.emacs.d"
        # Copy symlink structure (each file is a symlink to the nix store)
        # into a writable directory so straight.el can create straight/ and custom.el
        cp -a "$MOUNT$HM_HOME_FILES/.emacs.d/." "$USER_HOME/.emacs.d/"
        # Resolve UID/GID from the target's passwd (chroot may not have /run set up)
        _uid=$(grep "^${TARGET_USER}:" "$MOUNT/etc/passwd" | cut -d: -f3)
        _gid=$(grep "^${TARGET_USER}:" "$MOUNT/etc/passwd" | cut -d: -f4)
        chown -R "$_uid:$_gid" "$USER_HOME/.emacs.d"
        # Nix store sources are read-only; make .emacs.d writable so emacs
        # can create subdirectories (auto-save/, straight/, custom.el, etc.)
        chmod -R u+w "$USER_HOME/.emacs.d"
        # If custom.el is a symlink to the nix store (read-only), replace it
        # with a writable copy so customize-save-customized can write to it
        if [[ -L "$USER_HOME/.emacs.d/custom.el" ]]; then
            _custom_target=$(readlink -f "$USER_HOME/.emacs.d/custom.el")
            rm "$USER_HOME/.emacs.d/custom.el"
            cp "$_custom_target" "$USER_HOME/.emacs.d/custom.el"
            chown "$_uid:$_gid" "$USER_HOME/.emacs.d/custom.el"
        fi
        echo "Created ~/.emacs.d from home-manager generation"
    else
        echo "Warning: home-manager generation found but no .emacs.d directory"
    fi
else
    echo "Warning: no home-manager generation found, emacs pre-download will be skipped"
fi

# Pre-install Rust stable toolchain and emacs packages (requires network).
# Skip in --chroot-only mode: clone copies these from the booted USB instead,
# and --base-only installs are intentionally minimal.
if [[ -z "$CHROOT_ONLY" ]]; then
    echo "=== Installing Rust stable toolchain ==="
    chroot "$MOUNT" /run/current-system/sw/bin/su - "$TARGET_USER" -c '
        rustup default stable
        rustup component add rust-src rust-analyzer clippy rustfmt
    ' || echo "Warning: Rust toolchain install failed (non-fatal)"

    # Pre-download emacs packages for air-gapped use
    # Load init.el with all machine labels enabled, triggering straight.el
    # to download every package. Save the labels to custom.el for first boot.
    echo "=== Pre-downloading emacs packages ==="
    chroot "$MOUNT" /run/current-system/sw/bin/su - "$TARGET_USER" -c '
        emacs --batch \
            --eval "(progn
                (setq user-init-file (expand-file-name \"init.el\" user-emacs-directory))
                (setq custom-file (expand-file-name \"custom.el\" user-emacs-directory)))" \
            -l ~/.emacs.d/init.el \
            --eval "(progn
                (my/load-modules (my/machine-labels-available))
                (customize-set-variable (quote my/machine-labels) (my/machine-labels-available))
                (customize-save-customized)
                (message \"Emacs packages downloaded and all machine labels enabled.\"))" \
            2>&1
    ' || echo "Warning: emacs package pre-download failed (non-fatal)"
fi

# Clean up: remove home-manager-managed files from .emacs.d so that
# home-manager activation on first boot can create its symlinks cleanly.
# Keep only runtime-generated dirs (elpaca, straight, elpa, auto-save, etc.)
if [[ -d "$USER_HOME/.emacs.d" ]] && [[ -n "${HM_HOME_FILES:-}" ]] && [[ -d "$MOUNT$HM_HOME_FILES/.emacs.d" ]]; then
    echo "=== Cleaning up .emacs.d for home-manager activation ==="
    # Remove each file/dir that home-manager would manage (exists in the generation)
    while IFS= read -r -d '' entry; do
        rel="${entry#$MOUNT$HM_HOME_FILES/.emacs.d/}"
        target="$USER_HOME/.emacs.d/$rel"
        if [[ -e "$target" ]] && [[ ! -d "$target" ]]; then
            rm -f "$target"
        fi
    done < <(find "$MOUNT$HM_HOME_FILES/.emacs.d" -not -type d -print0)
    # Remove empty directories left behind (but not dirs with runtime content)
    find "$USER_HOME/.emacs.d" -type d -empty -delete 2>/dev/null || true
    echo "Removed home-manager-managed files, kept runtime downloads"
fi

# Remove native .so modules from the chroot pre-download — they may be
# corrupt (the chroot build env differs from the real runtime).
# The Nix-compiled vterm-module.so is provided via user profile site-lisp.
# Do NOT delete .elc files — they are valid and straight.el needs them
# for its build state and dependency resolution.
find "$USER_HOME/.emacs.d/straight" -name '*.so' -delete 2>/dev/null || true

# Clean up chroot mounts (kill lingering processes first so /dev unmounts cleanly)
fuser -km "$MOUNT" 2>/dev/null || true
sleep 1
umount "$MOUNT/sys" 2>/dev/null || true
umount "$MOUNT/proc" 2>/dev/null || true
umount "$MOUNT/dev" 2>/dev/null || umount -l "$MOUNT/dev" 2>/dev/null || true
sync

echo "=== Post-install complete ==="
if [[ -z "$CHROOT_ONLY" ]]; then
    echo "Archive data has been copied to the USB's nix store."
    echo "GC roots protect the data from garbage collection."
fi
if [[ -z "$CHROOT_ONLY" ]]; then
    echo "Chroot tasks (emacs packages, Rust toolchain) completed."
else
    echo "Chroot tasks completed (downloads skipped in chroot-only mode)."
fi
