{ config, pkgs, ... }:

## Main user config
{
  imports = [
  ];

  home.packages = [
    pkgs.cowsay
  ];
}
