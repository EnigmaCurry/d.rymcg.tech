{ config, pkgs, ... }:

# References:
#  https://www.bekk.christmas/post/2021/16/dotfiles-with-nix-and-home-manager
#  https://nix-community.github.io/home-manager/options.html
{
  # Core packages:
  home.packages = [
    pkgs.coreutils
    pkgs.procps
    pkgs.less
    pkgs.psmisc
    pkgs.gnused
    pkgs.gnugrep
    pkgs.findutils
    pkgs.ripgrep
    pkgs.gotty
  ];
}
