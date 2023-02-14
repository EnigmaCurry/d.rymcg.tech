{ config, pkgs, ... }:

{
  imports = [
    ./base.nix
    ./docker.nix
    ./emacs.nix
    ./git.nix
    ./ssh.nix
    ./python.nix
  ];
}
