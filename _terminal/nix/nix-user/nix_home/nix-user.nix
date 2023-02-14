{ config, pkgs, ... }:

# NB the files in nix_home are copied into the image at ~/.config/nixpkgs/
# The nixpkgs directory is also copied to the same location.
# So you should reference imports as a relative path of the nixpkgs directory as if they all exist in the same directory:
{
  imports = [ ./common.nix ];
}
