# Wireguard

This configuration is for a standalone Wireguard VPN server. 

## d.rymcg.tech provides two different wireguard configs

This config is not to be confused with the other wireguard config that
is integrated with [Traefik](../traefik/README.md#wireguard-vpn). This
config is used as a generic wireguard service that is more flexible
than the one integrated with Traefik, but this has fewer batteries
included, and you are more on your own with regards to routing and
translation.

Reasons you may wish to use this wireguard config:

 * If you want to tunnel your outgoing internet traffic from anywhere
   through a fixed public gateway (droplet / VPS).
 * If you want to run a private server from random locations, and have
   no ability to open a public port on your internet router.
 * If you want to create a generic VPN, for multiple clients, that you
   can use as a base layer network to build your own services on top
   of (and no built-in integration with Traefik).

Reasons you may wish to use the
[Traefik](../traefik/README.md#wireguard-vpn) wireguard instead:

 * If you want to run a private HTTP server in the cloud, acessible
   from several clients in various locations (eg. a company wide
   intranet service).
 * If you want to run a private HTTP server at a fixed location (home,
   office), accessible from the cloud, and you *are capable* of
   opening a public port for wireguard (eg. 51820) through your local
   internet router.
 * If you want to create a public gateway for your private HTTP
   servers located at fixed locations (home/office).

