{ config, pkgs, ... }:

# https://nix-community.github.io/home-manager/options.html#opt-programs.emacs.enable
{
  programs.emacs = {
    enable = true;
    extraPackages = epkgs: [
      epkgs.nix-mode
      epkgs.magit
      epkgs.dockerfile-mode
      epkgs.docker-compose-mode
      epkgs.docker-tramp
      epkgs.markdown-mode
    ];
  };
}
