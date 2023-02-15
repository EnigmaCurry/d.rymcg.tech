{ config, pkgs, ... }:

{
  ## Import all the non-personalized config here:
  ## As long as this part doesn't change often, the docker build will
  ## be faster, needing only to process the user config in home.nix.
  imports = [
    ./base.nix
    ./base/core.nix
    ./base/docker.nix
    ./base/python.nix
    ./base/development.nix
  ];
}
