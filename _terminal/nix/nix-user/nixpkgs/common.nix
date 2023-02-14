{ config, pkgs, ... }:

{
  ## Import all the non-user config:
  imports = [
    ./base.nix
    ./base/core.nix
    ./base/docker.nix
    ./base/python.nix
    ./base/development.nix
  ];
}
