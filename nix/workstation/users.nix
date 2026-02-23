# User account for the workstation
{ config, lib, pkgs, userName, ... }:

{
  users.users.${userName} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "audio" "input" "networkmanager" ];
    initialPassword = userName;
  };

  # Allow wheel group to sudo
  security.sudo.wheelNeedsPassword = true;

  # Default shell
  users.defaultUserShell = pkgs.bash;
}
