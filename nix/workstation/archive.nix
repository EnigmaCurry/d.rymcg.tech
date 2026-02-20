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

    # Per-project Docker image GC roots
    echo "Docker images:"
    img_count=0
    for root in "$gcroot_dir"/workstation-usb-image-*; do
      [[ -L "$root" ]] || continue
      name=$(basename "$root")
      proj="''${name#workstation-usb-image-}"
      target=$(readlink "$root")
      size=$(du -sh "$target" 2>/dev/null | cut -f1)
      echo "  $proj: $target ($size)"
      img_count=$((img_count + 1))
    done

    # ComfyUI variant files
    for root in "$gcroot_dir"/workstation-usb-comfyui-*; do
      [[ -L "$root" ]] || continue
      name=$(basename "$root")
      filename="''${name#workstation-usb-comfyui-}"
      target=$(readlink "$root")
      size=$(du -sh "$target" 2>/dev/null | cut -f1)
      echo "  comfyui/$filename ($size)"
      img_count=$((img_count + 1))
    done

    # Legacy monolithic archive
    legacy_root="$gcroot_dir/workstation-usb-archive"
    if [[ -L "$legacy_root" ]]; then
      target=$(readlink "$legacy_root")
      size=$(du -sh "$target" 2>/dev/null | cut -f1)
      echo "  (legacy archive): $target ($size)"
      img_count=$((img_count + 1))
    fi

    if [[ $img_count -eq 0 ]]; then
      echo "  (none)"
    fi

    echo ""

    # Show ISOs if present
    isos_root="$gcroot_dir/workstation-usb-isos"
    if [[ -L "$isos_root" ]]; then
      target=$(readlink "$isos_root")
      echo "ISOs:"
      ls -lh "$target"/*.iso 2>/dev/null | awk '{print "  " $NF " (" $5 ")"}'
    else
      echo "ISOs: not installed"
    fi

    echo ""

    # Show Docker CE packages if present
    docker_root="$gcroot_dir/workstation-usb-docker-packages"
    if [[ -L "$docker_root" ]]; then
      target=$(readlink "$docker_root")
      echo "Docker CE packages:"
      find "$target" -name '*.deb' -o -name '*.rpm' 2>/dev/null | while read f; do
        echo "  $(basename "$f") ($(du -h "$f" | cut -f1))"
      done
    else
      echo "Docker CE packages: not installed"
    fi
  '';

  # Helper script: restore archived Docker images
  workstation-usb-restore-images = pkgs.writeShellScriptBin "workstation-usb-restore-images" ''
    set -euo pipefail
    archive_dir="/var/workstation/images/x86_64"
    if [[ ! -d "$archive_dir" ]] || [[ -z "$(ls -A "$archive_dir" 2>/dev/null)" ]]; then
      echo "Error: No Docker image archive found on this workstation." >&2
      echo "Run workstation-usb-post-install to copy archive data." >&2
      exit 1
    fi

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

      # Symlink _archive in the d.rymcg.tech repo to /var/workstation
      archive_link="/home/user/git/vendor/enigmacurry/d.rymcg.tech/_archive"
      if [[ ! -e "$archive_link" ]]; then
        mkdir -p /home/user/git/vendor/enigmacurry/d.rymcg.tech
        chown user: /home/user/git /home/user/git/vendor \
          /home/user/git/vendor/enigmacurry /home/user/git/vendor/enigmacurry/d.rymcg.tech
        ln -sfn /var/workstation "$archive_link"
        chown -h user:user "$archive_link"
        echo "_archive: linked -> /var/workstation"
      fi

      # Per-project Docker image directories
      for root in "$gcroot_dir"/workstation-usb-image-*; do
        [[ -L "$root" ]] || continue
        name=$(basename "$root")
        proj="''${name#workstation-usb-image-}"
        store_path=$(readlink "$root")
        if [[ ! -d "$store_path" ]]; then
          echo "$proj: WARNING store path $store_path does not exist!"
          continue
        fi
        ln -sfn "$store_path" "/var/workstation/images/x86_64/$proj"
        echo "$proj: linked -> $store_path"
      done

      # ComfyUI variant files (individual .tar.gz files in the store)
      comfyui_count=0
      for root in "$gcroot_dir"/workstation-usb-comfyui-*; do
        [[ -L "$root" ]] || continue
        name=$(basename "$root")
        filename="''${name#workstation-usb-comfyui-}"
        store_path=$(readlink "$root")
        if [[ ! -e "$store_path" ]]; then
          echo "comfyui/$filename: WARNING store path does not exist!"
          continue
        fi
        mkdir -p "/var/workstation/images/x86_64/comfyui"
        ln -sfn "$store_path" "/var/workstation/images/x86_64/comfyui/$filename"
        comfyui_count=$((comfyui_count + 1))
      done
      [[ $comfyui_count -gt 0 ]] && echo "comfyui: linked $comfyui_count variant files"

      # Legacy: monolithic archive GC root (backward compat)
      legacy_root="$gcroot_dir/workstation-usb-archive"
      if [[ -L "$legacy_root" ]]; then
        store_path=$(readlink "$legacy_root")
        if [[ -d "$store_path" ]]; then
          count=0
          for item in "$store_path"/*; do
            [[ -e "$item" ]] || continue
            ln -sfn "$item" "/var/workstation/images/x86_64/$(basename "$item")"
            count=$((count + 1))
          done
          echo "legacy archive: linked $count items"
        fi
      fi

      # ISOs
      isos_root="$gcroot_dir/workstation-usb-isos"
      if [[ -L "$isos_root" ]]; then
        store_path=$(readlink "$isos_root")
        if [[ -d "$store_path" ]]; then
          count=0
          for item in "$store_path"/*; do
            [[ -e "$item" ]] || continue
            ln -sfn "$item" "/var/workstation/isos/$(basename "$item")"
            count=$((count + 1))
          done
          echo "ISOs: linked $count items"
        fi
      fi

      # Docker CE packages
      docker_root="$gcroot_dir/workstation-usb-docker-packages"
      if [[ -L "$docker_root" ]]; then
        store_path=$(readlink "$docker_root")
        if [[ -d "$store_path" ]]; then
          count=0
          for item in "$store_path"/*; do
            [[ -e "$item" ]] || continue
            ln -sfn "$item" "/var/workstation/docker-packages/$(basename "$item")"
            count=$((count + 1))
          done
          echo "Docker packages: linked $count items"
        fi
      fi
    '';
  };
}
