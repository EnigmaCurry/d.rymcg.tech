{ config, pkgs, ... }:

{
  imports = [
    ./common/packages.nix
    ./common/docker.nix
    ./common/python.nix
    ./common/development.nix
    ./common/git.nix
    ./common/bash.nix
    ./common/powerline-go.nix
    ./common/emacs.nix
  ];
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = builtins.getEnv "NIX_HOMEMANAGER_VERSION";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
