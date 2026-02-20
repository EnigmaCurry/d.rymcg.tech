# Docker and libvirt configuration for the workstation
{ config, lib, pkgs, ... }:

{
  # Enable Docker daemon
  virtualisation.docker.enable = true;

  # Enable libvirtd for virt-manager / QEMU / KVM
  virtualisation.libvirtd.enable = true;

  # Trust the Docker bridge so container traffic passes the firewall
  networking.firewall.trustedInterfaces = [ "docker0" ];

  # Prevent systemd-networkd from managing Docker's veth interfaces
  systemd.network.networks."10-docker-veth" = {
    matchConfig.Driver = "veth";
    linkConfig.Unmanaged = "yes";
  };

  # Only admin gets local docker and libvirtd access
  # (user can use remote Docker contexts and user-level QEMU sessions)
  users.users.admin.extraGroups = [ "docker" "libvirtd" ];

  # Traefik UID reservation for Docker containers
  users.users.traefik = {
    isSystemUser = true;
    group = "traefik";
  };
  users.groups.traefik = {};
}
