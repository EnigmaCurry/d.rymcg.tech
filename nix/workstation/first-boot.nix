# First-boot configuration and offline rebuild support
#
# Pins flake inputs and the no-sudo variant closure so nixos-install
# copies them to targets (enabling offline nixos-rebuild and offline
# admin/no-sudo cloning).
#
# On first boot of a cloned workstation, syncs settings.nix in the
# writable repo to match the installed configuration variant.
{ config, lib, pkgs, nixpkgs, home-manager, self
, sway-home, swayHomeInputs, nix-flatpak, sway-home-src, org-src
, vendor-git-repos, firefox-addons, userName
, noSudoSystemPath ? null, ... }:

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
  # and --override-input for vendor-git-repos (requires internet for
  # binary substitutes unless the target has a full build closure)
  rebuildScript = pkgs.writeShellScript "workstation-rebuild" ''
    set -euo pipefail
    FLAKE_DIR="/home/${userName}/git/vendor/enigmacurry/d.rymcg.tech"
    if [[ ! -d "$FLAKE_DIR/.git" ]]; then
      echo "Error: $FLAKE_DIR not found (workstation-clone-repos must run first)" >&2
      exit 1
    fi
    export HOME="''${HOME:-/root}"
    ${pkgs.git}/bin/git config --global --add safe.directory "$FLAKE_DIR"
    exec nixos-rebuild "$@" \
      --flake "$FLAKE_DIR#workstation" \
      --override-input vendor-git-repos "${vendor-git-repos}"
  '';

in
{
  # Pin all flake inputs into the system closure so they survive nixos-install
  # and are available for offline nixos-rebuild on the target
  environment.etc."workstation/flake-inputs".text = flakeInputPaths;

  # Expose the rebuild helper
  environment.etc."workstation/rebuild".source = rebuildScript;

  # Pin the no-sudo variant closure so nixos-install copies it to the target.
  # The clone script reads this path to install the no-sudo variant when
  # creating a two-account (admin + unprivileged) system.
  environment.etc."workstation/system-no-sudo" = lib.mkIf (noSudoSystemPath != null) {
    text = "${noSudoSystemPath}\n";
  };

  # First-boot settings sync service
  # After cloning, syncs settings.nix in the writable repo to match
  # the installed configuration. This ensures future nixos-rebuild
  # commands use the correct settings.
  systemd.services.workstation-first-boot = {
    description = "Sync workstation settings after clone";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" "workstation-clone-repos.service" ];
    requires = [ "workstation-clone-repos.service" ];

    unitConfig = {
      ConditionPathExists = "/etc/workstation-clone-settings";
    };

    path = with pkgs; [ coreutils gnused ];

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

      CHANGED=""

      # Update userName in settings.nix (takes effect on next rebuild)
      if [[ "$NEW_USER" != "$OLD_USER" ]]; then
        echo "Updating settings.nix: userName = \"$NEW_USER\""
        sed -i "s/userName = \"$OLD_USER\"/userName = \"$NEW_USER\"/" "$SETTINGS"
        CHANGED=1
      fi

      # Update sudoUser in settings.nix (takes effect on next rebuild)
      if [[ "$SUDO_USER" != "true" ]]; then
        echo "Updating settings.nix: sudoUser = false"
        sed -i "s/sudoUser = true/sudoUser = false/" "$SETTINGS"
        CHANGED=1
      fi

      if [[ -n "$CHANGED" ]]; then
        echo "settings.nix updated for future nixos-rebuild"
      else
        echo "No settings changes needed"
      fi

      # Clean up trigger file
      rm -f /etc/workstation-clone-settings
      echo "First-boot settings sync complete"
    '';
  };
}
