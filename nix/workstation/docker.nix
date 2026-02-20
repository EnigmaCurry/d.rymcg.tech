# Docker and libvirt configuration for the workstation
{ config, lib, pkgs, ... }:

{
  # Docker daemon disabled — this workstation uses remote Docker contexts
  virtualisation.docker.enable = false;

  # Enable libvirtd for virt-manager / QEMU / KVM
  virtualisation.libvirtd.enable = true;

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
