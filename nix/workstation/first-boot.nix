# First-boot configuration via nixos-rebuild
# When a cloned workstation has different settings (username, sudo, etc.),
# this service:
# 1. Reads desired settings from /etc/workstation-clone-settings
# 2. Edits settings.nix to match
# 3. Runs nixos-rebuild boot --offline to build a consistent closure
# 4. Renames the user if needed, moves the home directory
# 5. Reboots into the new closure
{ config, lib, pkgs, nixpkgs, home-manager, self
, sway-home, swayHomeInputs, nix-flatpak, sway-home-src, org-src
, vendor-git-repos, firefox-addons, userName, ... }:

let
  # List all flake inputs so they become runtime dependencies of the system
  # closure (and thus get copied by nixos-install). The /etc file creates
  # a reference that prevents garbage collection.
  flakeInputPaths = lib.concatStringsSep "\n" [
    "${nixpkgs}"
    "${home-manager}"
    "${sway-home}"
    "${nix-flatpak}"
    "${firefox-addons}"
    "${sway-home-src}"
    "${org-src}"
    "${vendor-git-repos}"
    "${self}"
    "${swayHomeInputs.emacs_enigmacurry}"
    "${swayHomeInputs.blog-rymcg-tech}"
    "${swayHomeInputs.nixos-vm-template}"
    "${swayHomeInputs.script-wizard}"
  ];

  # Helper script that wraps nixos-rebuild with the correct flake path
  # and --override-input for vendor-git-repos
  rebuildScript = pkgs.writeShellScript "workstation-rebuild" ''
    set -euo pipefail
    FLAKE_DIR="/home/${userName}/git/vendor/enigmacurry/d.rymcg.tech"
    if [[ ! -d "$FLAKE_DIR/.git" ]]; then
      echo "Error: $FLAKE_DIR not found (workstation-clone-repos must run first)" >&2
      exit 1
    fi
    # Allow git to read the repo when running as root (e.g. from first-boot service)
    ${pkgs.git}/bin/git config --global --add safe.directory "$FLAKE_DIR"
    exec nixos-rebuild "$@" \
      --flake "$FLAKE_DIR#workstation" \
      --override-input vendor-git-repos "${vendor-git-repos}" \
      --offline
  '';

in
{
  # Pin all flake inputs into the system closure so they survive nixos-install
  # and are available for offline nixos-rebuild on the target
  environment.etc."workstation/flake-inputs".text = flakeInputPaths;

  # Expose the rebuild helper
  environment.etc."workstation/rebuild".source = rebuildScript;

  # First-boot configuration service
  systemd.services.workstation-first-boot = {
    description = "First-boot configuration via nixos-rebuild";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" "workstation-clone-repos.service" ];
    before = [ "greetd.service" "display-manager.service" ];
    requires = [ "workstation-clone-repos.service" ];

    unitConfig = {
      ConditionPathExists = "/etc/workstation-clone-settings";
    };

    path = with pkgs; [ bash coreutils gnused gawk nixos-rebuild nix util-linux systemd ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      set -euo pipefail

      # Source the clone settings (CLONE_USERNAME, CLONE_SUDO_USER)
      source /etc/workstation-clone-settings

      OLD_USER="${userName}"
      NEW_USER="''${CLONE_USERNAME:-$OLD_USER}"
      SUDO_USER="''${CLONE_SUDO_USER:-true}"

      FLAKE_DIR="/home/$OLD_USER/git/vendor/enigmacurry/d.rymcg.tech"
      SETTINGS="$FLAKE_DIR/nix/workstation/settings.nix"

      if [[ ! -f "$SETTINGS" ]]; then
        echo "Error: $SETTINGS not found" >&2
        exit 1
      fi

      NEEDS_REBUILD=""

      # Update userName if different
      if [[ "$NEW_USER" != "$OLD_USER" ]]; then
        echo "Updating settings.nix: userName = \"$NEW_USER\""
        sed -i "s/userName = \"$OLD_USER\"/userName = \"$NEW_USER\"/" "$SETTINGS"
        NEEDS_REBUILD=1
      fi

      # Update sudoUser if different
      if [[ "$SUDO_USER" != "true" ]]; then
        echo "Updating settings.nix: sudoUser = false"
        sed -i "s/sudoUser = true/sudoUser = false/" "$SETTINGS"
        NEEDS_REBUILD=1
      fi

      if [[ -z "$NEEDS_REBUILD" ]]; then
        echo "No settings changes needed, cleaning up"
        rm -f /etc/workstation-clone-settings
        exit 0
      fi

      # Run nixos-rebuild boot --offline
      echo "Running nixos-rebuild boot --offline..."
      bash /etc/workstation/rebuild boot 2>&1 || {
        echo "nixos-rebuild failed, reverting settings.nix" >&2
        if [[ "$NEW_USER" != "$OLD_USER" ]]; then
          sed -i "s/userName = \"$NEW_USER\"/userName = \"$OLD_USER\"/" "$SETTINGS"
        fi
        if [[ "$SUDO_USER" != "true" ]]; then
          sed -i "s/sudoUser = false/sudoUser = true/" "$SETTINGS"
        fi
        exit 1
      }
      echo "nixos-rebuild boot succeeded"

      # Rename user if needed
      if [[ "$NEW_USER" != "$OLD_USER" ]]; then
        echo "=== Renaming user: $OLD_USER -> $NEW_USER ==="

        # Rename in /etc/passwd, /etc/shadow, /etc/group
        sed -i "s/^$OLD_USER:/$NEW_USER:/" /etc/passwd
        sed -i "s|:/home/$OLD_USER:|:/home/$NEW_USER:|" /etc/passwd
        sed -i "s/^$OLD_USER:/$NEW_USER:/" /etc/shadow
        sed -i "s/^$OLD_USER:/$NEW_USER:/" /etc/group
        sed -i -E "s/([:,])$OLD_USER(,|$)/\1$NEW_USER\2/g" /etc/group

        # Move home directory
        if [[ -d "/home/$OLD_USER" ]] && [[ ! -d "/home/$NEW_USER" ]]; then
          echo "Moving /home/$OLD_USER -> /home/$NEW_USER"
          mv "/home/$OLD_USER" "/home/$NEW_USER"
        fi

        # Move per-user nix profiles
        OLD_PROFILE="/nix/var/nix/profiles/per-user/$OLD_USER"
        NEW_PROFILE="/nix/var/nix/profiles/per-user/$NEW_USER"
        if [[ -d "$OLD_PROFILE" ]] && [[ ! -d "$NEW_PROFILE" ]]; then
          echo "Moving nix profiles: $OLD_USER -> $NEW_USER"
          mv "$OLD_PROFILE" "$NEW_PROFILE"
        fi

        # Fix ownership of .local (home-manager gcroots)
        if [[ -d "/home/$NEW_USER/.local" ]]; then
          NEW_UID=$(awk -F: "/^$NEW_USER:/{print \$3}" /etc/passwd)
          NEW_GID=$(awk -F: "/^$NEW_USER:/{print \$4}" /etc/passwd)
          chown -R "$NEW_UID:$NEW_GID" "/home/$NEW_USER/.local"
        fi
      fi

      # Clean up trigger and reboot
      rm -f /etc/workstation-clone-settings

      echo "=== First-boot configuration complete, rebooting ==="
      systemctl reboot
    '';
  };
}
