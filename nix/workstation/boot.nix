# Boot configuration for USB workstation
{ config, lib, pkgs, ... }:

{
  # Use latest kernel for broadest hardware support
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # UEFI systemd-boot (also set by disk-image.nix, but explicit here for clarity)
  boot.loader.systemd-boot.enable = true;
  # Critical: don't modify host machine's UEFI NVRAM
  boot.loader.efi.canTouchEfiVariables = false;

  # Root partition auto-grows on first boot via boot.growPartition
  # (already enabled by disk-image.nix)
}
