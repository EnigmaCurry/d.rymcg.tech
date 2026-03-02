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

      # Grow the physical partition
      # Exit 0 = grew, exit 1 = already full size (NOCHANGE)
      rc=0
      ${pkgs.cloud-utils.guest}/bin/growpart "$parent" "$partNum" || rc=$?
      if [ "$rc" -eq 1 ]; then
        echo "Partition already full size, nothing to do."
        exit 0
      elif [ "$rc" -ne 0 ]; then
        exit "$rc"
      fi

      # Partition grew — resize LUKS dm-crypt mapping if present.
      # Reloads the dm table with updated sector count. The key (stored in
      # the kernel keyring) is referenced by the table and stays untouched.
      if ${pkgs.cryptsetup}/bin/cryptsetup status cryptroot >/dev/null 2>&1; then
        old_table=$(${pkgs.lvm2}/bin/dmsetup table cryptroot)
        luks_offset=$(echo "$old_table" | ${pkgs.gawk}/bin/awk '{print $8}')
        new_part_sectors=$(${pkgs.util-linux}/bin/blockdev --getsz /dev/disk/by-partlabel/nixos)
        new_data_sectors=$((new_part_sectors - luks_offset))
        new_table=$(echo "$old_table" | ${pkgs.gawk}/bin/awk -v ns="$new_data_sectors" '{$2=ns; print}')
        ${pkgs.lvm2}/bin/dmsetup suspend cryptroot
        ${pkgs.lvm2}/bin/dmsetup load cryptroot --table "$new_table"
        ${pkgs.lvm2}/bin/dmsetup resume cryptroot
      fi

      # Resize the filesystem to fill the new space
      ROOT_DEV=$(${pkgs.util-linux}/bin/findmnt -nro SOURCE /)
      FSTYPE=$(${pkgs.util-linux}/bin/findmnt -nro FSTYPE /)
      case "$FSTYPE" in
        btrfs) ${pkgs.btrfs-progs}/bin/btrfs filesystem resize max / ;;
        ext*)  ${pkgs.e2fsprogs}/bin/resize2fs "$ROOT_DEV" ;;
      esac
    '';
  };
}
