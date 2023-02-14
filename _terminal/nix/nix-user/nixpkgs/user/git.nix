{ config, pkgs, ... }:

{
  # https://nix-community.github.io/home-manager/options.html#opt-programs.git.enable
  programs.git = {
    enable = true;
    userEmail = "idunno@example.com";
    userName = "i-forogt-to-set-this-up";
  };
}
