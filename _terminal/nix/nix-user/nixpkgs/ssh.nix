{ config, pkgs, ... }:

# https://nix-community.github.io/home-manager/options.html#opt-programs.git.enable
{
  home.packages = [
    pkgs.openssh
    pkgs.sshfs
    pkgs.keychain
  ];
}
