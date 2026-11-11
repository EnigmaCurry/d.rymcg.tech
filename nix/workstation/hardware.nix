# Hardware support for real x86_64 machines (USB boot)
{ config, lib, pkgs, ... }:

{
  # Redistributable firmware (WiFi, GPU, etc.)
  hardware.enableRedistributableFirmware = true;

  # initrd modules — only what's needed to find and mount root filesystem
  # (GPU drivers load after boot from rootfs, keeping initrd small)
  boot.initrd.availableKernelModules = [
    # USB storage
    "usb_storage" "uas"
    # SATA/NVMe
    "ahci" "nvme"
    # USB host controllers
    "xhci_pci" "ehci_pci"
    # Filesystems needed at boot
    "ext4" "btrfs" "crc32c-cryptoapi" "vfat"
    # LUKS / dm-crypt (for optional encryption)
    "dm_mod" "dm_crypt"
    "aes" "aes_generic" "xts" "ecb" "sha256"
    # Virtio (for VM testing)
    "virtio_pci" "virtio_blk" "virtio_scsi" "virtio_net"
  ];

  # Include cryptsetup in initrd for optional LUKS support
  boot.initrd.extraUtilsCommands = ''
    copy_bin_and_libs ${pkgs.cryptsetup}/bin/cryptsetup
  '';

  # Conditionally open LUKS if the root partition is encrypted.
  # Runs after device discovery, before root filesystem mount.
  # For unencrypted systems, cryptsetup isLuks returns false and this is a no-op.
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    if cryptsetup isLuks /dev/disk/by-partlabel/nixos 2>/dev/null; then
      echo "Opening encrypted root partition..."
      cryptsetup luksOpen /dev/disk/by-partlabel/nixos cryptroot
      udevadm settle
    fi
  '';

  # Kernel modules loaded after boot (GPU, KVM, WiFi)
  boot.kernelModules = [
    "kvm-intel" "kvm-amd"
    "iwlwifi"
    "i915" "amdgpu" "nouveau"
  ];

  # Bluetooth
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # zram swap (compressed in-memory swap)
  zramSwap = {
    enable = true;
    memoryPercent = 50;
    algorithm = "zstd";
  };
}
