# Workstation USB

Build a bootable NixOS USB drive that bundles everything needed to
deploy and manage d.rymcg.tech infrastructure without internet access:
all workstation tools, a sway desktop environment, read-only reference
copies of all git repos (with full history), the Docker image archive,
OS installation ISOs, and Docker CE offline installer packages.

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

On first boot, a systemd service clones a writable copy of
d.rymcg.tech from the bundled bare repo into
`~/git/vendor/enigmacurry/d.rymcg.tech`, with the GitHub remote
already configured. The `_archive/` directory is symlinked to
`/var/workstation/` so all d.rymcg.tech tools work seamlessly with the
nix store data.

## Prerequisites

 * A Linux workstation with [Nix](https://nixos.org/download/) installed
 * A completed [image archive](ARCHIVE.md) at `_archive/images/x86_64/`
 * A 128+ GB USB drive (see [size estimates](#size-estimates))

## Commands

All workstation USB commands are available through the `d.rymcg.tech`
CLI. Every command accepts `--help` for full usage details.

```bash
d.rymcg.tech workstation-usb-image                    # build raw disk image
d.rymcg.tech workstation-usb-test-vm                  # test image in a QEMU VM
d.rymcg.tech workstation-usb-install /dev/sdX          # direct install to USB
d.rymcg.tech workstation-usb-clone /dev/sdX            # clone booted USB to another device
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
1. Present an interactive archive category selector
2. Build the NixOS system closure
3. Partition the USB (1 GB ESP + rest ext4)
4. Install NixOS via `nixos-install`
5. Copy selected archive data into the USB's nix store
6. Pre-download emacs packages and Rust toolchain for air-gapped use

Default passwords match the username (`admin`/`admin`,
`user`/`user`). Change them on first boot with `passwd`.

### Method 2: Build a disk image

Build a raw `.img` file that can be written to any USB drive with `dd`.
Uses loop devices (requires sudo) instead of a QEMU VM.

By default, the image includes all archive data (Docker images, ISOs,
Docker CE packages) found in `_archive/`. An interactive category
selector lets you choose which archive categories to include, so you
can skip large items like AI/ML images (~43 GB) to build a smaller
image. The image size is auto-calculated to fit the selected data
plus headroom.

```bash
# Build the full image (includes archive data, auto-sized)
d.rymcg.tech workstation-usb-image

# Write to USB
sudo dd if=_archive/workstation-usb.img of=/dev/sdX bs=4M status=progress conv=fsync
```

The category selector presents four groups, all selected by default:

 * **Docker images: AI/ML** (~43 GB) — comfyui, open-webui, invokeai,
   ollama, kokoro
 * **Docker images: Services** (~21 GB) — everything else
 * **OS images / ISOs** (~7 GB)
 * **Docker CE packages** (~200 MB)

If AI/ML images are selected and ComfyUI is present, a follow-up
prompt lets you choose which GPU variants to include (ROCm, CUDA,
Intel, CPU).

To build a smaller base image without archive data:

```bash
# Build base OS only (~10 GB, skips category selection)
d.rymcg.tech workstation-usb-image --base-only

# Write to USB
sudo dd if=_archive/workstation-usb-base.img of=/dev/sdX bs=4M status=progress conv=fsync

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

### Method 3: Clone from a booted USB

Once you have a working workstation USB, you can clone it to another
drive directly — no build host, network access, or `nix build`
required. The clone reuses the running system closure from
`/run/current-system` and copies archive GC roots from the booted
USB's nix store.

```bash
# On the booted workstation USB, with a second drive attached:
d.rymcg.tech workstation-usb-clone /dev/sdX

# Or install base OS only, without archive data:
d.rymcg.tech workstation-usb-clone --base-only /dev/sdX
```

The `workstation-usb-clone` command is also available directly in PATH
on the booted USB (installed via `environment.systemPackages`), so it
works even without the writable repo clone.

This will:
1. Resolve the system closure from `/run/current-system`
2. Partition the target (1 GB ESP + rest ext4)
3. Install NixOS via `nixos-install --system`
4. Copy all `workstation-usb-*` GC roots to the target's nix store
5. Run chroot tasks (emacs packages, Rust toolchain)

### Testing with a VM

After building an image, you can boot it in a QEMU virtual machine to
verify everything works before writing to a USB drive. The VM uses a
CoW (copy-on-write) overlay, so the original image is never modified.

```bash
# Test the full image
d.rymcg.tech workstation-usb-test-vm

# Test the base-only image
d.rymcg.tech workstation-usb-test-vm --base

# Test in air-gapped mode (no network)
d.rymcg.tech workstation-usb-test-vm --no-network

# SSH into the running VM
ssh -o StrictHostKeyChecking=no -p 10022 user@localhost
```

| Option | Description |
|--------|-------------|
| `--image FILE` | Disk image path (default: auto-detected) |
| `--base` | Use the base-only image |
| `--memory MB` | RAM in MB (default: 4096) |
| `--cpus N` | Number of CPUs (default: all cores) |
| `--ssh-port PORT` | Host SSH port forwarding (default: 10022) |
| `--no-network` | Disable networking (simulate air-gapped environment) |
| `--display TYPE` | QEMU display: `gtk`, `sdl`, `none` (default: `gtk`) |

Requires OVMF firmware for UEFI boot and KVM for hardware
acceleration.

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

Download Debian, Fedora, and Raspberry Pi OS images for offline server
provisioning:

```bash
d.rymcg.tech workstation-usb-download-isos
```

| Option | Description |
|--------|-------------|
| `--debian-only` | Download only Debian ISO |
| `--fedora-only` | Download only Fedora ISO |
| `--raspi-only` | Download only Raspberry Pi OS Lite image |
| `--check` | Show what would be downloaded |

### Docker CE offline packages

Download Docker CE `.deb` and `.rpm` packages for offline Docker
installation on Debian, Raspberry Pi OS, and Fedora servers:

```bash
d.rymcg.tech workstation-usb-download-docker-packages
```

| Option | Description |
|--------|-------------|
| `--debian-only` | Download only Debian (amd64) packages |
| `--raspios-only` | Download only Raspberry Pi OS (arm64) packages |
| `--fedora-only` | Download only Fedora packages |
| `--check` | Show what would be downloaded |

## What's on the USB

### System

 * NixOS with the latest kernel and broad hardware support
 * Sway window manager with greetd/tuigreet login
 * PipeWire audio
 * NetworkManager for WiFi/Ethernet
 * Firefox with extensions (uBlock Origin, Dark Reader, Vimium,
   Multi-Account Containers, Temporary Containers), DuckDuckGo
   default search, telemetry disabled, HTTPS-only mode
 * Thunar file manager with volume management
 * Flatpak with Flathub (Bazaar pre-installed)
 * Docker daemon (installed but disabled on boot; enable with
   `sudo systemctl start docker`)
 * libvirtd / virt-manager / QEMU for VM management
 * All d.rymcg.tech required tools plus development utilities
 * Full sway-home environment (emacs with pre-downloaded packages,
   tmux, shell config, etc.)
 * Rust toolchain (stable, pre-installed with rust-src,
   rust-analyzer, clippy, rustfmt)
 * Network diagnostics (nmap, tcpdump, mtr, socat, step-cli, rclone)
 * Disk/recovery tools (ddrescue, testdisk, smartmontools, ntfs3g)
 * Serial console tools (minicom, picocom, ipmitool)
 * Crypto/security tools (gnupg, age, pass)

### Bundled data (in nix store, GC-rooted)

 * Bare git repos with full history:
   d.rymcg.tech, sway-home, emacs, blog.rymcg.tech, org
   (nixos-vm-template is provided by sway-home)
 * Writable clone of d.rymcg.tech (created on first boot from
   bare repo, with GitHub remote pre-configured)
 * Docker image archive (~64 GB, ~170 images):
   AI/ML (~43 GB), Services (~21 GB)
 * Debian, Fedora, and Raspberry Pi OS images (~8 GB)
 * Docker CE .deb/.rpm packages for Debian, Raspberry Pi OS,
   and Fedora (~0.5 GB)

### User accounts

| User | Groups | Purpose |
|------|--------|---------|
| `admin` | wheel, docker, libvirtd, video, audio | Administration (has sudo, Docker, VMs) |
| `user` | video, audio | Daily use (remote Docker contexts, user QEMU) |

Default passwords match the username. Change them on first boot.

## Using the USB workstation

### Check bundled data

```bash
workstation-usb-info
```

Shows what archive data is installed, including image count and sizes.

### Clone to another drive

```bash
workstation-usb-clone /dev/sdX
```

Clone the entire workstation (OS + archive data) to another USB drive
or disk. No network or build tools required. See
[Method 3](#method-3-clone-from-a-booted-usb) above.

### Restore Docker images to a server

```bash
workstation-usb-restore-images
```

This wraps `d.rymcg.tech image-restore` with the correct archive
directory pointed at the nix store.

### Install Docker on a server

```bash
d.rymcg.tech install-docker
```

Interactive installer that supports both online (get.docker.com) and
offline (bundled .deb/.rpm packages) installation, for both local and
remote Docker contexts.

### Access bundled data

Archive data is stored under `/var/workstation/` and symlinked into
the bundled d.rymcg.tech repo so tools work seamlessly:

```
~/git/vendor/enigmacurry/d.rymcg.tech/_archive -> /var/workstation
```

| Path | Contents |
|------|----------|
| `/var/workstation/images/x86_64/` | Docker image `.tar.gz` files |
| `/var/workstation/isos/` | Debian, Fedora, and Raspberry Pi OS images |
| `/var/workstation/docker-packages/` | Docker CE `.deb`/`.rpm` files |

### Access git repos

Read-only bare repos are in the nix store, symlinked into the user's
home directory:

```
~/git/vendor-nix/enigmacurry/d.rymcg.tech     (bare, read-only)
~/git/vendor-nix/enigmacurry/sway-home         (bare, read-only)
~/git/vendor-nix/enigmacurry/emacs             (bare, read-only)
~/git/vendor-nix/enigmacurry/blog.rymcg.tech   (bare, read-only)
~/git/vendor-nix/enigmacurry/org               (bare, read-only)
```

A writable clone of d.rymcg.tech is created automatically on first
boot:

```
~/git/vendor/enigmacurry/d.rymcg.tech          (writable, full history)
```

To create writable clones of other repos:

```bash
git clone ~/git/vendor-nix/enigmacurry/sway-home ~/git/vendor/enigmacurry/sway-home
```

## Size estimates

| Component | Size |
|-----------|------|
| NixOS system + all packages | ~5 GB |
| sway-home packages (emacs, dev tools) | ~3 GB |
| Git repos in nix store | ~50 MB |
| Docker images: AI/ML | ~43 GB |
| Docker images: Services | ~21 GB |
| ISOs (Debian + Fedora + Raspberry Pi OS) | ~8 GB |
| Docker CE packages (.deb + .rpm) | ~0.5 GB |
| Operating headroom | ~5 GB |
| **Total (all categories)** | **~86 GB** |
| **Total (services only, no AI/ML)** | **~43 GB** |

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
  docker.nix                          # Docker + libvirtd (Docker disabled on boot)
  desktop.nix                         # Sway, greetd, PipeWire, Firefox, Thunar, Flatpak
  home-manager.nix                    # sway-home, Firefox extensions, Flatpak apps
  workstation-packages.nix            # CLI tools, dev tools, nixos-install-tools
  repos.nix                           # Bare git repos, writable clone service
  archive.nix                         # GC roots, helper scripts (info, clone, restore)
  installer/
    install-to-device.sh              # Direct install script
    clone-to-device.sh                # Clone from booted USB script
    post-install.sh                   # Archive data copy + chroot tasks
```
