{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  ## How do I read an env var here??? 
  #home.username = "${NIX_USER_NAME}";
  home.username = "nix-user";
  home.homeDirectory = "/home/nix-user";

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.

  ## how do I read an env var here???
  #home.stateVersion = "${NIX_HOMEMANAGER_VERSION}";
  home.stateVersion = "22.11";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
