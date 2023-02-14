{ config, pkgs, ... }:

{
  # development, testing, and deployment tools:
  home.packages = [
    pkgs.gnumake
    pkgs.ncurses
    pkgs.htop
    pkgs.openssl
    pkgs.apacheHttpd
    pkgs.jq
    pkgs.git
    pkgs.inetutils
    pkgs.openssh
    pkgs.sshfs
    pkgs.keychain
  ];
}
