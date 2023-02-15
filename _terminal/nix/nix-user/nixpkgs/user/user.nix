{ config, pkgs, ... }:

## Main user config
{
  imports = [
    ./emacs.nix
    ./ssh.nix
    ./bash.nix
    ./powerline-go.nix
  ];

  home.packages = [
    pkgs.cowsay
  ];
}
