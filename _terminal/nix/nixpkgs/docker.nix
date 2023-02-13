{ config, pkgs, ... }:

{
  # Packages to install in userspace:
  home.packages = [
    pkgs.docker-client
    pkgs.docker-compose
    pkgs.docker-buildx
  ];
}
