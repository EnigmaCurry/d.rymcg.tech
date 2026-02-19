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

  # Disk image configuration
  image.baseName = "workstation-usb";
  image.format = "raw";
  image.efiSupport = true;

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Allow unfree packages (firmware, fonts, etc.)
  nixpkgs.config.allowUnfree = true;

  # Timezone and locale
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";
}
