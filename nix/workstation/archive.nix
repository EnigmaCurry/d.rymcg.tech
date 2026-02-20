# Archive data management for the workstation USB
# Handles GC root symlinks and helper scripts for the Docker image archive,
# ISOs, and Docker CE packages that are copied in post-install.
{ config, lib, pkgs, ... }:

let
  # Helper script: show what data is bundled on this workstation
  workstation-usb-info = pkgs.writeShellScriptBin "workstation-usb-info" ''
    echo "=== Workstation USB Info ==="
    echo ""

    gcroot_dir="/nix/var/nix/gcroots"

    for name in workstation-usb-archive workstation-usb-isos workstation-usb-docker-packages; do
      root="$gcroot_dir/$name"
      if [[ -L "$root" ]]; then
        target=$(readlink "$root")
        size=$(du -sh "$target" 2>/dev/null | cut -f1)
        echo "$name: $target ($size)"
      else
        echo "$name: not installed"
      fi
    done

    echo ""

    # Show archive details if present
    archive_root="$gcroot_dir/workstation-usb-archive"
    if [[ -L "$archive_root" ]]; then
      target=$(readlink "$archive_root")
      count=$(find "$target" -name '*.tar.gz' 2>/dev/null | wc -l)
      echo "Docker image archive: $count images"
    fi

    # Show ISOs if present
    isos_root="$gcroot_dir/workstation-usb-isos"
    if [[ -L "$isos_root" ]]; then
      target=$(readlink "$isos_root")
      echo "ISOs:"
      ls -lh "$target"/*.iso 2>/dev/null | awk '{print "  " $NF " (" $5 ")"}'
    fi

    # Show Docker CE packages if present
    docker_root="$gcroot_dir/workstation-usb-docker-packages"
    if [[ -L "$docker_root" ]]; then
      target=$(readlink "$docker_root")
      echo "Docker CE packages:"
      find "$target" -name '*.deb' -o -name '*.rpm' 2>/dev/null | while read f; do
        echo "  $(basename "$f") ($(du -h "$f" | cut -f1))"
      done
    fi
  '';

  # Helper script: restore archived Docker images
  workstation-usb-restore-images = pkgs.writeShellScriptBin "workstation-usb-restore-images" ''
    set -euo pipefail
    gcroot="/nix/var/nix/gcroots/workstation-usb-archive"
    if [[ ! -L "$gcroot" ]]; then
      echo "Error: No Docker image archive found on this workstation." >&2
      echo "Run workstation-usb-post-install to copy archive data." >&2
      exit 1
    fi
    archive_dir=$(readlink "$gcroot")

    # Check for d.rymcg.tech CLI
    drymcg=$(command -v d.rymcg.tech 2>/dev/null || true)
    if [[ -z "$drymcg" ]]; then
      echo "Error: d.rymcg.tech CLI not found in PATH." >&2
      echo "Add ~/git/vendor/enigmacurry/d.rymcg.tech/_scripts/user to PATH." >&2
      exit 1
    fi

    echo "Restoring Docker images from: $archive_dir"
    exec d.rymcg.tech image-restore --archive-dir="$archive_dir" "$@"
  '';

in
{
  environment.systemPackages = [
    workstation-usb-info
    workstation-usb-restore-images
  ];

  # Create data directories for symlinks to GC-rooted store paths
  # Layout matches _archive/ so d.rymcg.tech tools work with the symlink
  systemd.tmpfiles.rules = [
    "d /var/workstation 0755 root root -"
    "d /var/workstation/images 0755 root root -"
    "d /var/workstation/images/x86_64 0755 root root -"
    "d /var/workstation/isos 0755 root root -"
    "d /var/workstation/docker-packages 0755 root root -"
    # Symlink _archive in the bundled d.rymcg.tech repo to /var/workstation
    "L+ /home/user/git/vendor/enigmacurry/d.rymcg.tech/_archive - user user - /var/workstation"
  ];

  # On boot, create convenience symlinks from /var/workstation/* to GC-rooted store paths
  systemd.services.workstation-usb-archive-links = {
    description = "Create symlinks to workstation archive data";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      gcroot_dir="/nix/var/nix/gcroots"
      echo "Checking GC roots in $gcroot_dir..."
      ls -la "$gcroot_dir"/workstation-usb-* 2>/dev/null || echo "No workstation GC roots found"
      for name in workstation-usb-archive workstation-usb-isos workstation-usb-docker-packages; do
        root="$gcroot_dir/$name"
        case "$name" in
          workstation-usb-archive)       target_dir="/var/workstation/images/x86_64" ;;
          workstation-usb-isos)          target_dir="/var/workstation/isos" ;;
          workstation-usb-docker-packages) target_dir="/var/workstation/docker-packages" ;;
        esac
        if [[ -L "$root" ]]; then
          store_path=$(readlink "$root")
          if [[ ! -d "$store_path" ]]; then
            echo "$name: WARNING store path $store_path does not exist!"
            continue
          fi
          count=0
          for item in "$store_path"/*; do
            [[ -e "$item" ]] || continue
            base=$(basename "$item")
            ln -sfn "$item" "$target_dir/$base"
            count=$((count + 1))
          done
          echo "$name: linked $count items from $store_path -> $target_dir"
        else
          echo "$name: no GC root at $root"
        fi
      done
    '';
  };
}
