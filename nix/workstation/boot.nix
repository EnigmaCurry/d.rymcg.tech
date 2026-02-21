# Boot configuration for USB workstation
{ config, lib, pkgs, ... }:

{
  # Use latest kernel for broadest hardware support
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # UEFI systemd-boot
  boot.loader.systemd-boot.enable = true;
  # Critical: don't modify host machine's UEFI NVRAM
  boot.loader.efi.canTouchEfiVariables = false;

  # Auto-grow root partition to fill USB on first boot
  boot.growPartition = true;
}
