# First-boot user rename via nixos-rebuild
# When a cloned workstation has a different username, this service:
# 1. Edits settings.nix to set the new username
# 2. Runs nixos-rebuild boot --offline to build a consistent closure
# 3. Renames the user in /etc/passwd, moves the home directory
# 4. Reboots into the new closure
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

  # First-boot rename service
  systemd.services.workstation-first-boot = {
    description = "First-boot user rename via nixos-rebuild";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" "workstation-clone-repos.service" ];
    before = [ "greetd.service" "display-manager.service" ];
    requires = [ "workstation-clone-repos.service" ];

    unitConfig = {
      ConditionPathExists = "/etc/workstation-clone-username";
    };

    path = with pkgs; [ coreutils gnused gawk nixos-rebuild nix util-linux systemd ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      set -euo pipefail

      NEW_USER=$(cat /etc/workstation-clone-username)
      OLD_USER="${userName}"

      if [[ -z "$NEW_USER" ]] || [[ "$NEW_USER" == "$OLD_USER" ]]; then
        echo "No rename needed (new=$NEW_USER, old=$OLD_USER), cleaning up trigger"
        rm -f /etc/workstation-clone-username
        exit 0
      fi

      echo "=== First-boot rename: $OLD_USER -> $NEW_USER ==="

      # Step 1: Edit settings.nix to set the new username
      FLAKE_DIR="/home/$OLD_USER/git/vendor/enigmacurry/d.rymcg.tech"
      SETTINGS="$FLAKE_DIR/nix/workstation/settings.nix"

      if [[ ! -f "$SETTINGS" ]]; then
        echo "Error: $SETTINGS not found" >&2
        exit 1
      fi

      echo "Updating settings.nix: userName = \"$NEW_USER\""
      sed -i "s/userName = \"$OLD_USER\"/userName = \"$NEW_USER\"/" "$SETTINGS"

      # Step 2: Run nixos-rebuild boot --offline
      echo "Running nixos-rebuild boot --offline..."
      bash /etc/workstation/rebuild boot 2>&1 || {
        echo "nixos-rebuild failed, reverting settings.nix" >&2
        sed -i "s/userName = \"$NEW_USER\"/userName = \"$OLD_USER\"/" "$SETTINGS"
        exit 1
      }
      echo "nixos-rebuild boot succeeded"

      # Step 3: Rename user in /etc/passwd, /etc/shadow, /etc/group
      echo "Renaming user in system files..."
      sed -i "s/^$OLD_USER:/$NEW_USER:/" /etc/passwd
      sed -i "s|:/home/$OLD_USER:|:/home/$NEW_USER:|" /etc/passwd
      sed -i "s/^$OLD_USER:/$NEW_USER:/" /etc/shadow
      sed -i "s/^$OLD_USER:/$NEW_USER:/" /etc/group
      sed -i -E "s/([:,])$OLD_USER(,|$)/\1$NEW_USER\2/g" /etc/group

      # Step 4: Move home directory
      if [[ -d "/home/$OLD_USER" ]] && [[ ! -d "/home/$NEW_USER" ]]; then
        echo "Moving /home/$OLD_USER -> /home/$NEW_USER"
        mv "/home/$OLD_USER" "/home/$NEW_USER"
      fi

      # Step 5: Move per-user nix profiles
      OLD_PROFILE="/nix/var/nix/profiles/per-user/$OLD_USER"
      NEW_PROFILE="/nix/var/nix/profiles/per-user/$NEW_USER"
      if [[ -d "$OLD_PROFILE" ]] && [[ ! -d "$NEW_PROFILE" ]]; then
        echo "Moving nix profiles: $OLD_USER -> $NEW_USER"
        mv "$OLD_PROFILE" "$NEW_PROFILE"
      fi

      # Step 6: Move home-manager gcroots
      OLD_GCROOTS="/home/$NEW_USER/.local/state/home-manager/gcroots"
      if [[ -d "$OLD_GCROOTS" ]]; then
        NEW_UID=$(awk -F: "/^$NEW_USER:/{print \$3}" /etc/passwd)
        NEW_GID=$(awk -F: "/^$NEW_USER:/{print \$4}" /etc/passwd)
        chown -R "$NEW_UID:$NEW_GID" "/home/$NEW_USER/.local"
      fi

      # Step 7: Clean up trigger and reboot
      echo "Removing trigger file"
      rm -f /etc/workstation-clone-username

      echo "=== Rename complete, rebooting into new closure ==="
      systemctl reboot
    '';
  };
}
