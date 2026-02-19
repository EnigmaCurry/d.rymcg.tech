# Boot configuration for USB workstation
{ config, lib, pkgs, ... }:

{
  # Use latest kernel for broadest hardware support
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # UEFI systemd-boot
  boot.loader.systemd-boot.enable = true;
  # Critical: don't modify host machine's UEFI NVRAM
  boot.loader.efi.canTouchEfiVariables = false;

  # Grow root partition to fill USB on first boot
  systemd.services.grow-root-partition = {
    description = "Expand root partition to fill USB drive";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    unitConfig = {
      # Only run once — creates a stamp file
      ConditionPathExists = "!/var/lib/grow-root-done";
    };
    path = [ pkgs.cloud-utils pkgs.e2fsprogs pkgs.util-linux ];
    script = ''
      set -euo pipefail
      ROOT_DEV=$(findmnt -n -o SOURCE /)
      # Get the parent disk and partition number
      DISK=$(lsblk -n -o PKNAME "$ROOT_DEV" | head -1)
      PARTNUM=$(lsblk -n -o MAJ:MIN "$ROOT_DEV" | head -1 | cut -d: -f2 | tr -d ' ')
      if [[ -n "$DISK" && -n "$PARTNUM" ]]; then
        echo "Growing partition $PARTNUM on /dev/$DISK"
        growpart "/dev/$DISK" "$PARTNUM" || true
        resize2fs "$ROOT_DEV" || true
      fi
      touch /var/lib/grow-root-done
    '';
  };
}
