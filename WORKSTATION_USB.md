# Workstation USB

Build a bootable NixOS USB drive that bundles everything needed to
deploy and manage d.rymcg.tech infrastructure without internet access:
all workstation tools, a sway desktop environment, read-only reference
copies of all git repos, the Docker image archive, OS installation
ISOs, and Docker CE offline installer packages.

## Why a USB workstation?

In air-gapped or disaster-recovery scenarios, you need a complete
workstation that can bootstrap servers from scratch — without depending
on package repositories, container registries, or even a network
connection. This USB drive is a self-contained ops environment: boot
any x86_64 machine, log in, and start deploying.

## Architecture

The system is a **mutable NixOS** installation on a USB drive. You can
`nixos-rebuild`, install packages, and make changes like any normal
NixOS system. However, all bundled reference data (git repos, Docker
image archive, ISOs, Docker CE packages) is stored in the nix store
and protected by GC roots — it cannot be accidentally deleted.

The build uses a **two-phase approach**: Nix builds the OS closure
(fast, ~10 GB), then a post-install step copies the large archive data
(~64 GB) into the USB's nix store. This avoids hashing tens of
gigabytes during flake evaluation.

## Prerequisites

 * A Linux workstation with [Nix](https://nixos.org/download/) installed
 * A completed [image archive](ARCHIVE.md) at `_archive/images/x86_64/`
 * A 128+ GB USB drive (see [size estimates](#size-estimates))

## Commands

All workstation USB commands are available through the `d.rymcg.tech`
CLI. Every command accepts `--help` for full usage details.

```bash
d.rymcg.tech workstation-usb-image                    # build raw disk image
d.rymcg.tech workstation-usb-install /dev/sdX          # direct install to USB
d.rymcg.tech workstation-usb-post-install /mnt         # copy archive data to USB
d.rymcg.tech workstation-usb-download-isos             # download OS ISOs
d.rymcg.tech workstation-usb-download-docker-packages  # download Docker CE packages
```

## Install methods

### Method 1: Direct install to USB device

The simplest approach. Partitions, formats, installs NixOS, sets
passwords, and copies archive data in one step.

```bash
d.rymcg.tech workstation-usb-install /dev/sdX
```

This will:
1. Build the NixOS system closure
2. Partition the USB (1 GB ESP + rest ext4)
3. Install NixOS via `nixos-install`
4. Copy archive data into the USB's nix store

Default passwords match the username (`admin`/`admin`,
`user`/`user`). Change them on first boot with `passwd`.

### Method 2: Build a disk image

Build a raw `.img` file that can be written to any USB drive with `dd`.
Uses loop devices (requires sudo) instead of a QEMU VM.

By default, the image includes all archive data (Docker images, ISOs,
Docker CE packages) found in `_archive/`. The image size is
auto-calculated to fit everything plus headroom.

```bash
# Build the full image (includes archive data, auto-sized)
d.rymcg.tech workstation-usb-image

# Write to USB
sudo dd if=_archive/workstation-usb.img of=/dev/sdX bs=4M status=progress conv=fsync
```

To build a smaller base image without archive data:

```bash
# Build base OS only (~10 GB)
d.rymcg.tech workstation-usb-image --base-only

# Write to USB
sudo dd if=_archive/workstation-usb.img of=/dev/sdX bs=4M status=progress conv=fsync

# Copy archive data separately
sudo mount /dev/sdX2 /mnt && sudo mount /dev/sdX1 /mnt/boot
d.rymcg.tech workstation-usb-post-install /mnt
sudo umount -R /mnt
```

| Option | Description |
|--------|-------------|
| `--size SIZE` | Override auto-calculated image size (e.g. `128G`) |
| `--output FILE` | Output path (default: `_archive/workstation-usb.img`) |
| `--base-only` | Build OS only, without archive data (smaller image) |
| `--dry-run` | Build system closure only, skip image creation |

On first boot, the root partition automatically expands to fill the
USB drive.

## Preparing archive data

Before building the USB, you should prepare the archive data that will
be bundled. The NixOS system itself builds without any of this — the
archive data is added in the post-install step.

### Docker image archive

Follow the [ARCHIVE.md](ARCHIVE.md) instructions to build the
complete image archive:

```bash
d.rymcg.tech image-archive --fail-fast --delete --verbose
```

### OS installation ISOs

Download Debian and Fedora ISOs for offline server provisioning:

```bash
d.rymcg.tech workstation-usb-download-isos
```

| Option | Description |
|--------|-------------|
| `--debian-only` | Download only Debian ISO |
| `--fedora-only` | Download only Fedora ISO |
| `--check` | Show what would be downloaded |

### Docker CE offline packages

Download Docker CE `.deb` and `.rpm` packages for offline Docker
installation on Debian and Fedora servers:

```bash
d.rymcg.tech workstation-usb-download-docker-packages
```

| Option | Description |
|--------|-------------|
| `--debian-only` | Download only Debian packages |
| `--fedora-only` | Download only Fedora packages |
| `--check` | Show what would be downloaded |

## What's on the USB

### System

 * NixOS with the latest kernel and broad hardware support
 * Sway window manager with greetd login
 * PipeWire audio
 * NetworkManager for WiFi/Ethernet
 * Docker daemon
 * All 17 d.rymcg.tech required tools plus development utilities
 * Full sway-home environment (emacs, tmux, shell config, etc.)

### Bundled data (in nix store, GC-rooted)

 * Read-only copies of all git repos:
   d.rymcg.tech, sway-home, emacs, blog.rymcg.tech, org,
   nixos-vm-template
 * Docker image archive (~64 GB, ~170 images)
 * Debian and Fedora ISOs (~8 GB)
 * Docker CE .deb/.rpm packages (~0.5 GB)

### User accounts

| User | Groups | Purpose |
|------|--------|---------|
| `admin` | wheel, docker, video, audio | Administration (has sudo) |
| `user` | docker, video, audio | Daily use |

Default passwords match the username. Change them on first boot.

## Using the USB workstation

### Check bundled data

```bash
workstation-usb-info
```

Shows what archive data is installed, including image count and sizes.

### Restore Docker images to a server

```bash
workstation-usb-restore-images
```

This wraps `d.rymcg.tech image-restore` with the correct archive
directory pointed at the nix store.

### Access bundled data

Archive data is symlinked at boot:

| Path | Contents |
|------|----------|
| `/var/workstation/archive/` | Docker image `.tar.gz` files |
| `/var/workstation/isos/` | Debian and Fedora ISOs |
| `/var/workstation/docker-packages/` | Docker CE `.deb`/`.rpm` files |

### Access git repos

All repos are symlinked into the user's home directory as read-only
nix store references:

```
~/git/vendor/enigmacurry/d.rymcg.tech
~/git/vendor/enigmacurry/sway-home
~/git/vendor/enigmacurry/emacs
~/git/vendor/enigmacurry/blog.rymcg.tech
~/git/vendor/enigmacurry/org
~/nixos-vm-template
```

To make editable copies, clone from the bundled source:

```bash
cp -r ~/git/vendor/enigmacurry/d.rymcg.tech ~/my-d.rymcg.tech
cd ~/my-d.rymcg.tech && git init
```

## Size estimates

| Component | Size |
|-----------|------|
| NixOS system + all packages | ~5 GB |
| sway-home packages (emacs, dev tools) | ~3 GB |
| Git repos in nix store | ~50 MB |
| Docker image archive | ~64 GB |
| ISOs (Debian + Fedora) | ~8 GB |
| Docker CE packages (.deb + .rpm) | ~0.5 GB |
| Operating headroom | ~5 GB |
| **Total** | **~86 GB** |

A 128 GB USB drive is recommended. A 256 GB drive provides ample room
for additional data.

## NixOS module layout

```
flake.nix                              # Top-level flake
nix/workstation/
  configuration.nix                    # Main config (imports all modules)
  hardware.nix                         # Hardware support, filesystems
  boot.nix                            # UEFI systemd-boot, growpart
  users.nix                           # admin + user accounts
  networking.nix                      # NetworkManager, firewall
  docker.nix                          # Docker daemon
  desktop.nix                         # Sway, greetd, PipeWire, fonts
  home-manager.nix                    # sway-home integration
  workstation-packages.nix            # CLI tools and dev tools
  repos.nix                           # Git repo symlinks
  archive.nix                         # GC roots, helper scripts
  installer/
    install-to-device.sh              # Direct install script
    post-install.sh                   # Archive data copy script
```
