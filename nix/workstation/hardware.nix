# Hardware support for real x86_64 machines (USB boot)
{ config, lib, pkgs, ... }:

{
  # Redistributable firmware (WiFi, GPU, etc.)
  hardware.enableRedistributableFirmware = true;

  # initrd modules for broad hardware support
  boot.initrd.availableKernelModules = [
    # USB storage
    "usb_storage" "uas"
    # SATA/NVMe
    "ahci" "nvme"
    # USB host controllers
    "xhci_pci" "ehci_pci"
    # Filesystems needed at boot
    "ext4" "vfat"
    # GPU (for early display)
    "i915" "amdgpu" "nouveau"
    # Virtio (for VM testing)
    "virtio_pci" "virtio_blk" "virtio_scsi" "virtio_net"
  ];

  # Kernel modules loaded after boot
  boot.kernelModules = [
    "kvm-intel" "kvm-amd"
    "iwlwifi"  # Intel WiFi
  ];

  # Root filesystem on USB (by label)
  # mkForce needed: disk-image.nix sets its own fileSystems that we override
  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-label/nixos-workstation";
    fsType = "ext4";
  };

  # EFI System Partition
  fileSystems."/boot" = lib.mkForce {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
    options = [ "umask=0077" ];
  };

  # zram swap (compressed in-memory swap)
  zramSwap = {
    enable = true;
    memoryPercent = 50;
    algorithm = "zstd";
  };
}
