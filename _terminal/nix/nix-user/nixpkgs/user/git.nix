{ config, pkgs, ... }:

{
  # https://nix-community.github.io/home-manager/options.html#opt-programs.git.enable
  programs.git = {
    userEmail = builtins.getEnv "NIX_GIT_EMAIL";
    userName = builtins.getEnv "NIX_GIT_USERNAME";
  };
}
