{ config, pkgs, ... }:

# References:
#  https://www.bekk.christmas/post/2021/16/dotfiles-with-nix-and-home-manager
#  https://nix-community.github.io/home-manager/options.html
{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "nix-user";
  home.homeDirectory = "/home/nix-user";

  # Packages to install in userspace:
  home.packages = [
    pkgs.findutils
    pkgs.procps
    pkgs.less
    pkgs.coreutils
    pkgs.openssh
    pkgs.ncurses
    pkgs.htop
    pkgs.openssl
    pkgs.apacheHttpd
    pkgs.jq
    pkgs.sshfs
    pkgs.gnumake
    pkgs.gnused
    pkgs.inetutils
  ];

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "22.11";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
