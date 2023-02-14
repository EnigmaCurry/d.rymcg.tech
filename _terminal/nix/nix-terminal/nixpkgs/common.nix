{ config, pkgs, ... }:

{
  imports = [ ./base.nix ./docker.nix ./emacs.nix ./python.nix ];
}
