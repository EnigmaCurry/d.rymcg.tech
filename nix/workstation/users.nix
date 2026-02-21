# User accounts for the workstation
{ config, lib, pkgs, ... }:

{
  # admin user with sudo access
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "audio" "input" "networkmanager" ];
    # Password set during install; default for image builds (change on first boot)
    initialPassword = "admin";
  };

  # Regular unprivileged user
  users.users.user = {
    isNormalUser = true;
    extraGroups = [ "video" "audio" "input" "networkmanager" ];
    initialPassword = "user";
  };

  # Allow wheel group to sudo
  security.sudo.wheelNeedsPassword = true;

  # Default shell
  users.defaultUserShell = pkgs.bash;
}
