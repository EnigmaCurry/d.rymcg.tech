{ config, pkgs, ... }:

{
  imports = [
    ./user/bash.nix
    ./user/powerline-go.nix
    ./user/emacs.nix
    ./user/ssh.nix
    ./user/git.nix
  ];
}
