# Main NixOS configuration for the workstation USB
{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware.nix
    ./boot.nix
    ./users.nix
    ./networking.nix
    ./docker.nix
    ./desktop.nix
    ./home-manager.nix
    ./workstation-packages.nix
    ./repos.nix
    ./archive.nix
  ];

  system.stateVersion = "25.11";
  nixpkgs.hostPlatform = "x86_64-linux";

  # Filesystem labels (must match what install-to-device.sh and
  # workstation-usb-image create: ESP label "ESP", root label "nixos")
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
    options = [ "umask=0077" ];
  };

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Allow unfree packages (firmware, fonts, etc.)
  nixpkgs.config.allowUnfree = true;

  # Timezone and locale
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";
}
