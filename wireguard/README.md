# Wireguard

This configuration is for a standalone Wireguard VPN server (no
integration with Traefik).

## d.rymcg.tech provides two different wireguard configs

This config is not to be confused with the other wireguard config that
is integrated with [Traefik](../traefik/README.md#wireguard-vpn). This
config is used as a generic wireguard service that is more flexible
than the one integrated with Traefik, but this has fewer batteries
included, and you are more on your own with regards to routing and
translation.

Reasons you may wish to use this wireguard config:

 * If you want to tunnel your outgoing internet traffic from anywhere,
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
   office), and you *are capable* of opening a public port for
   wireguard (eg. 51820) through your local internet router/firewall,
   for making it accessible from the cloud.
 * If you want to create a public cloud gateway for your private HTTP
   servers located at fixed locations (home/office).

## Config

```
make config
```

Enter the following required config settings:

 * `WIREGUARD_HOST` the fully qualified domain name or public IP
   address of the wireguard service (eg. `wireguard.example.com`). If
   you enter a DNS name, it must be pointed to the public IP address
   of the server.
 * `WIREGUARD_PEERS` the comma separated list of all the peer configs
   to create. Each peer name must be alphanumeric with no spaces, no
   dashes, no underscores. (eg. `client1,client2,client3`)

There are additional/optional configuration you can make in your .env
file by hand, see the comments in [.env-dist](.env-dist).

## Install

```
make install
```

