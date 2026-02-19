# Home-manager integration using sway-home modules
# Follows the pattern from nixos-vm-template/profiles/home-manager.nix
{ config, lib, pkgs, sway-home, swayHomeInputs, nix-flatpak, ... }:

{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    # Pass inputs that sway-home modules expect
    extraSpecialArgs = {
      inputs = swayHomeInputs;
      userName = "user";
    };

    # Configure home-manager for the regular user
    users.user = { pkgs, ... }: {
      imports = [
        nix-flatpak.homeManagerModules.nix-flatpak
        sway-home.homeModules.home
        sway-home.homeModules.emacs
        sway-home.homeModules.rust
        sway-home.homeModules.nixos-vm-template
      ];

      # Install packages from sway-home + home-manager CLI (mutable system)
      home.packages = import "${sway-home}/modules/packages.nix" { inherit pkgs; }
        ++ [ swayHomeInputs.script-wizard.packages.${pkgs.stdenv.hostPlatform.system}.default ]
        ++ [ pkgs.home-manager ];

      programs.home-manager.enable = true;
    };
  };
}
