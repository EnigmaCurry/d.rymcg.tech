# Flake input pinning and offline rebuild support
#
# Pins flake inputs so nixos-install copies them to targets,
# enabling offline nixos-rebuild on the installed system.
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

  # Wrapper that makes `nixos-rebuild switch` (etc.) just work by
  # injecting --flake and --override-input automatically.
  # References the real nixos-rebuild by store path to avoid recursion.
  realNixosRebuild = "${pkgs.nixos-rebuild}/bin/nixos-rebuild";
  nixos-rebuild-wrapper = pkgs.writeShellScriptBin "nixos-rebuild" ''
    set -euo pipefail
    FLAKE_DIR="/home/${userName}/git/vendor/enigmacurry/d.rymcg.tech"
    if [[ ! -d "$FLAKE_DIR/.git" ]]; then
      echo "Error: $FLAKE_DIR not found (workstation-clone-repos must run first)" >&2
      exit 1
    fi
    export HOME="''${HOME:-/root}"
    ${pkgs.git}/bin/git config --global --add safe.directory "$FLAKE_DIR"
    exec ${realNixosRebuild} "$@" \
      --flake "$FLAKE_DIR#workstation" \
      --override-input vendor-git-repos "${vendor-git-repos}"
  '';

in
{
  # Pin all flake inputs into the system closure so they survive nixos-install
  # and are available for offline nixos-rebuild on the target
  environment.etc."workstation/flake-inputs".text = flakeInputPaths;

  # Replace bare nixos-rebuild with our flake-aware wrapper
  environment.systemPackages = [ nixos-rebuild-wrapper ];
}
