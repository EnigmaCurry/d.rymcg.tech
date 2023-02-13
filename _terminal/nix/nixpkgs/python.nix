{ config, pkgs, ... }:

{
  # Packages to install in userspace:
  home.packages = [
    pkgs.python311
  ];
}
