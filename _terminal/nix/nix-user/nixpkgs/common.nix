{ config, pkgs, ... }:

{
  imports = [
    ./base.nix
    ./docker.nix
    ./emacs.nix
    ./git.nix
    ./python.nix
  ];
}
