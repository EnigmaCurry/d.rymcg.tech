# Docker and libvirt configuration for the workstation
{ config, lib, pkgs, userName, ... }:

{
  # Install Docker CLI without enabling the daemon service
  virtualisation.docker.enable = true;
  systemd.services.docker.wantedBy = lib.mkForce [];
  systemd.sockets.docker.wantedBy = lib.mkForce [];

  # Enable libvirtd for virt-manager / QEMU / KVM
  virtualisation.libvirtd.enable = true;

  # Grant the primary user local docker and libvirtd access
  users.users.${userName}.extraGroups = [ "docker" "libvirtd" ];

  # Traefik UID reservation for Docker containers
  users.users.traefik = {
    isSystemUser = true;
    group = "traefik";
  };
  users.groups.traefik = {};
}
