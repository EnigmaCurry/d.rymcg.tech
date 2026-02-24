# Networking configuration for the workstation
{ config, lib, pkgs, hostName, ... }:

{
  networking.hostName = hostName;

  # NetworkManager for easy WiFi/Ethernet management
  networking.networkmanager.enable = true;

  # Firewall
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ ];
  networking.firewall.allowedUDPPorts = [ ];
}
