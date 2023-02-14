{ config, pkgs, ... }:

# https://nix-community.github.io/home-manager/options.html#opt-programs.git.enable
{
  programs.git = {
    enable = true;
    userEmail = "nobody@example.com";
    userName = "i-forogt-to-set-this-up";
  };
}
