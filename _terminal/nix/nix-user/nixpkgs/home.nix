{ config, pkgs, ... }:

## NB put all user personalized config in ./user/user.nix
{
  imports = [
    ./common.nix
    ./user/user.nix
  ];
}
