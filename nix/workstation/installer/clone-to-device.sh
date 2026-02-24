#!/usr/bin/env bash
## Clone the booted workstation USB to another device
## Usage: clone-to-device.sh [OPTIONS] /dev/sdX
## Must be run as root on a booted workstation USB.
## No build or network access required.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

prompt_password() {
    local label="$1"
    local varname="$2"
    while true; do
        read -s -p "Password for $label: " _pw1; echo
        read -s -p "Confirm password for $label: " _pw2; echo
        if [[ "$_pw1" == "$_pw2" ]]; then
            eval "$varname=\$_pw1"
            return
        fi
        echo "Passwords do not match. Try again."
    done
}

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

# Discover the primary user from the booted USB
SRC_USER=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1; exit}' /etc/passwd)
echo "Source user: $SRC_USER"

# Account setup prompts
echo ""
echo "=== Account Setup ==="
ACCOUNT_MODE=$(script-wizard choose "Account mode" \
    "Single account with sudo" \
    "Two accounts (admin + unprivileged)")

ADMIN_USER=""
ADMIN_PASS=""
USER_PASS=""
NEW_USER=""

if [[ "$ACCOUNT_MODE" == "Single"* ]]; then
    read -e -p "Username [$SRC_USER]: " NEW_USER
    NEW_USER="${NEW_USER:-$SRC_USER}"
    prompt_password "$NEW_USER" USER_PASS
else
    read -e -p "Username [$SRC_USER]: " NEW_USER
    NEW_USER="${NEW_USER:-$SRC_USER}"
    prompt_password "$NEW_USER" USER_PASS
    read -e -p "Admin username [admin]: " ADMIN_USER
    ADMIN_USER="${ADMIN_USER:-admin}"
    prompt_password "$ADMIN_USER" ADMIN_PASS
fi

# Safety check
echo ""
echo "WARNING: This will ERASE ALL DATA on $DEVICE"
echo ""
lsblk "$DEVICE"
echo ""
if [[ -n "$ADMIN_USER" ]]; then
    echo "Accounts: $ADMIN_USER (admin/sudo), $NEW_USER (unprivileged)"
else
    echo "Account: $NEW_USER (with sudo)"
fi
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

sed -i 's/^title .*/title NixOS Workstation/' "$MOUNT/boot/loader/entries/"*.conf

echo ""
echo "=== Archiving flake inputs for offline nixos-rebuild ==="
nix flake archive --to "local?root=$MOUNT" "/home/$SRC_USER/git/vendor/enigmacurry/d.rymcg.tech"
mkdir -p "$MOUNT/root/.cache/nix"
cp -a /root/.cache/nix/fetcher-cache-v*.sqlite* "$MOUNT/root/.cache/nix/" 2>/dev/null || true
echo "Flake inputs archived"

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

# Discover target username from the installed system
TGT_USER=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1; exit}' "$MOUNT/etc/passwd")
echo "Target user: $TGT_USER"

# Write trigger file for first-boot rename (if username differs)
if [[ "$NEW_USER" != "$TGT_USER" ]]; then
    echo "Will rename '$TGT_USER' -> '$NEW_USER' on first boot via nixos-rebuild"
    echo "$NEW_USER" > "$MOUNT/etc/workstation-clone-username"
fi

echo ""
echo "=== Running post-install chroot tasks ==="
if [[ -x "$SCRIPT_DIR/post-install.sh" ]]; then
    "$SCRIPT_DIR/post-install.sh" "$MOUNT" --chroot-only
else
    echo "Warning: post-install.sh not found, skipping chroot tasks."
fi

# Copy pre-built home directory resources from the booted USB to the clone.
# These are normally downloaded by post-install.sh but that requires network.
# Copying from the running system makes the clone fully air-gapped.
echo ""
echo "=== Copying home directory resources from booted USB ==="
_src_home="/home/$SRC_USER"
_dst_home="$MOUNT/home/$TGT_USER"
_uid=$(grep "^${TGT_USER}:" "$MOUNT/etc/passwd" | cut -d: -f3)
_gid=$(grep "^${TGT_USER}:" "$MOUNT/etc/passwd" | cut -d: -f4)

_copy_home_resource() {
    local rel_path="$1"
    local description="$2"
    local src="$_src_home/$rel_path"
    local dst="$_dst_home/$rel_path"
    if [[ -e "$src" ]]; then
        local size
        size=$(du -sh "$src" | cut -f1)
        echo "  Copying $description ($size)..."
        mkdir -p "$(dirname "$dst")"
        cp -a "$src" "$dst"
        chown -R "$_uid:$_gid" "$dst"
    else
        echo "  Skipping $description: not found on source"
    fi
}

_copy_home_resource ".rustup" "Rust toolchain"
_copy_home_resource ".cargo" "Cargo config and cache"
_copy_home_resource ".emacs.d/straight" "emacs packages (straight.el)"
_copy_home_resource ".local/share/fonts" "nerd fonts"

# Copy custom.el if it's a regular file (not a home-manager symlink)
if [[ -f "$_src_home/.emacs.d/custom.el" ]] && [[ ! -L "$_src_home/.emacs.d/custom.el" ]]; then
    echo "  Copying emacs custom.el..."
    mkdir -p "$_dst_home/.emacs.d"
    cp -a "$_src_home/.emacs.d/custom.el" "$_dst_home/.emacs.d/custom.el"
    chown "$_uid:$_gid" "$_dst_home/.emacs.d/custom.el"
fi

# Remove hardware-specific native modules from copied emacs packages
find "$_dst_home/.emacs.d/straight" -name '*.so' -delete 2>/dev/null || true

# Ensure .emacs.d directory itself is owned by the user (mkdir -p creates it as root)
# so home-manager activation can create symlinks (emacs.org, init.el, etc.)
if [[ -d "$_dst_home/.emacs.d" ]]; then
    chown "$_uid:$_gid" "$_dst_home/.emacs.d"
fi

echo ""
echo "=== Configuring accounts ==="
echo "${TGT_USER}:${USER_PASS}" | chroot "$MOUNT" /run/current-system/sw/bin/chpasswd

if [[ -n "$ADMIN_USER" ]]; then
    chroot "$MOUNT" /run/current-system/sw/bin/useradd \
        -m -G wheel "$ADMIN_USER"
    echo "${ADMIN_USER}:${ADMIN_PASS}" | chroot "$MOUNT" /run/current-system/sw/bin/chpasswd
    chroot "$MOUNT" /run/current-system/sw/bin/gpasswd -d "$TGT_USER" wheel
    echo "Created admin account '$ADMIN_USER' with sudo"
    echo "Removed sudo from '$TGT_USER'"
fi

echo ""
echo "=== Clone complete ==="
echo "You can now boot from $DEVICE."
if [[ -n "$ADMIN_USER" ]]; then
    echo "Accounts: $ADMIN_USER (admin/sudo), $NEW_USER (unprivileged)"
else
    echo "Account: $NEW_USER (with sudo)"
fi
if [[ -f "$MOUNT/etc/workstation-clone-username" ]]; then
    echo "First boot will rename '$TGT_USER' -> '$NEW_USER' via nixos-rebuild (auto-reboots once)."
fi
echo "The root partition will auto-expand on first boot."
