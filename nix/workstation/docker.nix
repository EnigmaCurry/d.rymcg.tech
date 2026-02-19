# Docker daemon configuration for the workstation
# Simplified from nixos-vm-template/profiles/docker.nix
{ config, lib, pkgs, ... }:

{
  # Enable Docker daemon
  virtualisation.docker.enable = true;

  # Trust the Docker bridge so container traffic passes the firewall
  networking.firewall.trustedInterfaces = [ "docker0" ];

  # Prevent systemd-networkd from managing Docker's veth interfaces
  systemd.network.networks."10-docker-veth" = {
    matchConfig.Driver = "veth";
    linkConfig.Unmanaged = "yes";
  };

  # Add both users to docker group
  users.users.admin.extraGroups = [ "docker" ];
  users.users.user.extraGroups = [ "docker" ];

  # Traefik UID reservation for Docker containers
  users.users.traefik = {
    isSystemUser = true;
    group = "traefik";
  };
  users.groups.traefik = {};
}
