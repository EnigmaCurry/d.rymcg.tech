# Boot configuration for USB workstation
{ config, lib, pkgs, ... }:

{
  # Use latest kernel for broadest hardware support
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # UEFI systemd-boot
  boot.loader.systemd-boot.enable = true;
  # Critical: don't modify host machine's UEFI NVRAM
  boot.loader.efi.canTouchEfiVariables = false;

  # Auto-grow root partition to fill the device on first boot.
  # Custom service replaces boot.growPartition to handle LUKS and btrfs.
  # The "nixos" partition is found by partlabel, grown to fill the disk,
  # then any LUKS container and filesystem are resized to match.
  systemd.services.growpart = {
    wantedBy = [ "-.mount" ];
    after = [ "-.mount" ];
    before = [ "systemd-growfs-root.service" "shutdown.target" ];
    conflicts = [ "shutdown.target" ];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutSec = "infinity";
    };
    script = ''
      set -euo pipefail
      PART=$(readlink -f /dev/disk/by-partlabel/nixos)
      # Extract parent device and partition number
      parent="$PART"
      while [ "''${parent%[0-9]}" != "''${parent}" ]; do
        parent="''${parent%[0-9]}"
      done
      partNum="''${PART#"''${parent}"}"
      # Handle NVMe "p" separator (e.g. /dev/nvme0n1p2)
      if [ "''${parent%[0-9]p}" != "''${parent}" ] && [ -b "''${parent%p}" ]; then
        parent="''${parent%p}"
      fi

      # Grow the physical partition (exit 1 = already full size)
      ${pkgs.cloud-utils.guest}/bin/growpart "$parent" "$partNum" || [ $? -eq 1 ]

      # If LUKS, resize the container so inner device sees new space
      if ${pkgs.cryptsetup}/bin/cryptsetup status cryptroot >/dev/null 2>&1; then
        ${pkgs.cryptsetup}/bin/cryptsetup resize cryptroot
      fi

      # Resize the filesystem
      ROOT_DEV=$(findmnt -nro SOURCE /)
      FSTYPE=$(findmnt -nro FSTYPE /)
      case "$FSTYPE" in
        btrfs) ${pkgs.btrfs-progs}/bin/btrfs filesystem resize max / ;;
        ext*)  ${pkgs.e2fsprogs}/bin/resize2fs "$ROOT_DEV" ;;
      esac
    '';
  };
}
