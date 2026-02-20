#!/usr/bin/env bash
## Post-install: copy archive data and pre-download packages for air-gapped use
## Usage: post-install.sh /mnt [ARCHIVE_ROOT] [--chroot-only]
## Must be run after nixos-install, while the USB is still mounted.
set -euo pipefail

MOUNT="${1:-}"
ARCHIVE_ROOT="${2:-}"
CHROOT_ONLY=""
if [[ "${3:-}" == "--chroot-only" ]] || [[ "${2:-}" == "--chroot-only" ]]; then
    CHROOT_ONLY=1
    # If --chroot-only was the second arg, clear ARCHIVE_ROOT
    if [[ "${2:-}" == "--chroot-only" ]]; then
        ARCHIVE_ROOT=""
    fi
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ARCHIVE_ROOT="${ARCHIVE_ROOT:-$FLAKE_DIR/_archive}"

if [[ -z "$MOUNT" ]]; then
    echo "Usage: $0 /mnt [ARCHIVE_ROOT] [--chroot-only]"
    echo "Copy archive data to a mounted NixOS workstation USB and"
    echo "pre-download packages (emacs, Rust) for air-gapped use."
    echo ""
    echo "The USB root filesystem must be mounted at the given path."
    echo ""
    echo "Options:"
    echo "  --chroot-only  Skip archive copying, only run chroot tasks"
    echo "                 (emacs packages, Rust toolchain)"
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

## Copy archive data to the USB's nix store (skipped with --chroot-only)
if [[ -z "$CHROOT_ONLY" ]]; then
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
fi

## Set up chroot environment for pre-download tasks
# Set up DNS so straight.el can fetch packages
mkdir -p "$MOUNT/etc"
cp -L /etc/resolv.conf "$MOUNT/etc/resolv.conf" 2>/dev/null || true

# Bind-mount /dev, /proc, /sys for chroot
mount --bind /dev "$MOUNT/dev" 2>/dev/null || true
mount --bind /proc "$MOUNT/proc" 2>/dev/null || true
mount --bind /sys "$MOUNT/sys" 2>/dev/null || true

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
USER_HOME="$MOUNT/home/user"
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
        _uid=$(grep '^user:' "$MOUNT/etc/passwd" | cut -d: -f3)
        _gid=$(grep '^user:' "$MOUNT/etc/passwd" | cut -d: -f4)
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

# Pre-install Rust stable toolchain for air-gapped use
echo "=== Installing Rust stable toolchain ==="
chroot "$MOUNT" /run/current-system/sw/bin/su - user -c '
    rustup default stable
    rustup component add rust-src rust-analyzer clippy rustfmt
' || echo "Warning: Rust toolchain install failed (non-fatal)"

# Pre-download emacs packages for air-gapped use
# Load init.el with all machine labels enabled, triggering straight.el
# to download every package. Save the labels to custom.el for first boot.
echo "=== Pre-downloading emacs packages ==="
chroot "$MOUNT" /run/current-system/sw/bin/su - user -c '
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

# Delete the entire straight/build/ directory. The chroot pre-download
# produces broken builds (corrupt .so, .elc compiled without native modules,
# broken autoloads). Source is fully cached in straight/repos/ so straight.el
# will rebuild everything from local source on first boot — no internet needed.
rm -rf "$USER_HOME/.emacs.d/straight/build" 2>/dev/null || true

# Clean up chroot mounts
echo "(Any 'target is busy' warnings below are harmless)"
umount "$MOUNT/sys" 2>/dev/null || true
umount "$MOUNT/proc" 2>/dev/null || true
umount "$MOUNT/dev" 2>/dev/null || true

echo "=== Post-install complete ==="
if [[ -z "$CHROOT_ONLY" ]]; then
    echo "Archive data has been copied to the USB's nix store."
    echo "GC roots protect the data from garbage collection."
fi
echo "Chroot tasks (emacs packages, Rust toolchain) completed."
