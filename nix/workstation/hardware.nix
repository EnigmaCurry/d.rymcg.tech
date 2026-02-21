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
    "ext4" "vfat"
    # Virtio (for VM testing)
    "virtio_pci" "virtio_blk" "virtio_scsi" "virtio_net"
  ];

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
