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
`nixos-rebuild switch`, install packages, and make changes like any
normal NixOS system. Bundled reference data (git repos, Docker image
archive, ISOs, Docker CE packages) is stored in the nix store and
protected by GC roots so routine garbage collection won't remove it.

The build uses a **two-phase approach**: Nix builds the OS closure
(fast, ~10 GB), then a post-install step copies the large archive data
(~64 GB) into the USB's nix store. This avoids hashing tens of
gigabytes during flake evaluation.

**Username is baked at build time.** Both `workstation-usb-image` and
`workstation-usb-install` prompt for a username before building. The
username is written to `settings.nix`, then the entire NixOS closure
is built with it. The default password equals the username (via
`initialPassword`). Clones are exact copies — no account setup, no
variant builds, no first-boot configuration service.

On first boot, a systemd service clones writable copies of
d.rymcg.tech and sway-home from the bundled bare repos into
`~/git/vendor/enigmacurry/`, with GitHub remotes already configured.
The `_archive/` directory is symlinked to `/var/workstation/` so all
d.rymcg.tech tools work seamlessly with the nix store data.

A `nixos-rebuild` wrapper is installed so that `sudo nixos-rebuild
switch` works out of the box — it automatically passes the correct
`--flake` and `--override-input` flags.

## Customization (settings.nix)

All per-user settings live in `nix/workstation/settings.nix`:

```nix
{
  userName = "user";
  sudoUser = true;
  remotes = {
    "d.rymcg.tech" = "https://github.com/EnigmaCurry/d.rymcg.tech.git";
    "sway-home" = "https://github.com/EnigmaCurry/sway-home.git";
    "emacs" = "https://github.com/EnigmaCurry/emacs.git";
    "blog.rymcg.tech" = "https://github.com/EnigmaCurry/blog.rymcg.tech.git";
    "org" = "https://github.com/EnigmaCurry/org.git";
  };
}
```

| Setting | Description |
|---------|-------------|
| `userName` | Login username (default password = username) |
| `sudoUser` | Whether the user gets sudo (wheel group) |
| `remotes` | Git remote URLs for all vendor repos |

The build scripts prompt for a username and update `settings.nix`
automatically. After customization, `git update-index
--skip-worktree` is applied so local changes don't appear in `git
status` while remaining visible to the Nix flake evaluator.

To edit settings manually:

```bash
# Edit settings
vi nix/workstation/settings.nix

# Hide from git status
git update-index --skip-worktree nix/workstation/settings.nix

# Undo if needed
git update-index --no-skip-worktree nix/workstation/settings.nix
```

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
```

## Install methods

### Method 1: Direct install to USB device

The simplest approach. Partitions, formats, installs NixOS, and copies
archive data in one step.

```bash
d.rymcg.tech workstation-usb-install /dev/sdX
```

This will:
1. Present an interactive archive category selector
2. Prompt for username (default: `user`)
3. Build the NixOS system closure with that username baked in
4. Partition the USB (1 GB ESP + rest ext4)
5. Install NixOS via `nixos-install`
6. Copy selected archive data into the USB's nix store
7. Pre-download emacs packages and Rust toolchain for air-gapped use

Default password matches the username. Change it on first boot with
`passwd`.

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

The build prompts for a username before building. The category
selector presents four groups, all selected by default:

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
USB's nix store. Clones are exact copies with the same username and
configuration.

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
2. Confirm device erase
3. Partition the target (1 GB ESP + rest ext4)
4. Install NixOS via `nixos-install --system`
5. Copy all `workstation-usb-*` GC roots to the target's nix store
6. Run chroot tasks (emacs packages, Rust toolchain)
7. Copy home directory resources (Rust toolchain, emacs packages,
   fonts) from the booted USB

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
 * Writable clones of d.rymcg.tech and sway-home (created on first
   boot from bare repos, with remotes from `settings.nix`)
 * Docker image archive (~64 GB, ~170 images):
   AI/ML (~43 GB), Services (~21 GB)
 * Debian, Fedora, and Raspberry Pi OS images (~8 GB)
 * Docker CE .deb/.rpm packages for Debian, Raspberry Pi OS,
   and Fedora (~0.5 GB)

### User account

A single user account is created with the username chosen at build
time. The user has sudo (wheel group) by default. Default password
matches the username — change it on first boot with `passwd`.

## Using the USB workstation

### Rebuild the system

`nixos-rebuild switch` works out of the box:

```bash
sudo nixos-rebuild switch
```

The installed `nixos-rebuild` is a wrapper that automatically passes
`--flake` and `--override-input` flags pointing at the local
d.rymcg.tech repo.

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

### Remove bundled archive data

If you no longer need the bundled archive data (Docker images, ISOs,
Docker CE packages), you can free the space by removing the GC root
symlinks and running garbage collection:

```bash
sudo rm /nix/var/nix/gcroots/workstation-usb-*
sudo nix-collect-garbage
```

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

Writable clones are created automatically on first boot:

```
~/git/vendor/enigmacurry/d.rymcg.tech          (writable, full history)
~/git/vendor/enigmacurry/sway-home             (writable, full history)
```

To create writable clones of the other repos:

```bash
git clone ~/git/vendor-nix/enigmacurry/emacs ~/git/vendor/enigmacurry/emacs
git clone ~/git/vendor-nix/enigmacurry/blog.rymcg.tech ~/git/vendor/enigmacurry/blog.rymcg.tech
git clone ~/git/vendor-nix/enigmacurry/org ~/git/vendor/enigmacurry/org
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
  settings.nix                         # Username, sudo, repo remote URLs
  configuration.nix                    # Main config (imports all modules)
  hardware.nix                         # Hardware support, filesystems
  boot.nix                            # UEFI systemd-boot, growpart
  users.nix                           # User account (from settings.nix)
  networking.nix                      # NetworkManager, firewall
  docker.nix                          # Docker + libvirtd (Docker disabled on boot)
  desktop.nix                         # Sway, greetd, PipeWire, Firefox, Thunar, Flatpak
  home-manager.nix                    # sway-home, Firefox extensions, Flatpak apps
  workstation-packages.nix            # CLI tools, dev tools, nixos-install-tools
  first-boot.nix                      # Flake input pinning, nixos-rebuild wrapper
  repos.nix                           # Bare git repos, writable clone service
  archive.nix                         # GC roots, helper scripts (info, clone, restore)
  installer/
    install-to-device.sh              # Direct install script
    clone-to-device.sh                # Clone from booted USB script
    post-install.sh                   # Archive data copy + chroot tasks
```
