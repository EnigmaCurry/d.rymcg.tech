{ config, pkgs, ... }:

{
  programs.emacs = {
    enable = true;
    extraPackages = epkgs: [
      epkgs.nix-mode
      epkgs.magit
      epkgs.dockerfile-mode
      epkgs.docker-compose-mode
      epkgs.docker-tramp
    ];
  };
}
