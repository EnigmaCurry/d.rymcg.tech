{ config, pkgs, ... }:

{
  imports = [
    ./user/ssh.nix
    ./user/git.nix
  ];
}
