# User account for the workstation
{ config, lib, pkgs, userName, sudoUser, ... }:

{
  users.users.${userName} = {
    isNormalUser = true;
    extraGroups = lib.optionals sudoUser [ "wheel" ]
      ++ [ "video" "audio" "input" "networkmanager" ];
    initialPassword = userName;
  };

  # Allow wheel group to sudo
  security.sudo.wheelNeedsPassword = true;

  # Default shell
  users.defaultUserShell = pkgs.bash;
}
