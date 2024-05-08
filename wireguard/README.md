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

Setup d.rymcg.tech according to the main [README.md](../README.md)

Create a public DNS entry for your wireguard server (eg.
`wireguard.example.com`) pointing to the IP address of your Docker
host server.

From this directory, run:

```
make config
```

Enter the following required config settings:

 * `WIREGUARD_HOST` enter the fully qualified domain name you chose
   for this wireguard service (eg. `wireguard.example.com`).
 * `WIREGUARD_PEERS` enter the comma separated list of all the peer
   configs to create. Each peer name must be alphanumeric with **no**
   spaces, **no** dashes, **no** underscores. (eg.
   `myclient1,myclient2,myclient3`)

There are additional/optional configuration you can make in your .env
file by hand, see the comments in [.env-dist](.env-dist).

## Install

From this directory, run:

```
make install
```

## Show the generated peer config files:

From this directory, run:

```
## Prints ALL of the peer configs:
make show-wireguard-peers
```

*All* of the peer config files will be printed to the screen in
sequence. Notice that they are each separated by a comment at the top
starting like `## /config/peer_myclient1/peer_myclient1.conf`.

If you want to setup mobile clients (android), you may instead wish to
see the QR encoded copy of the same information. Run:

```
## Prints the QR code for every peer config:
make show-wireguard-peers-qr
```

## Linux client script

There are many different clients you can choose from, including:

 * [wg-quick](https://git.zx2c4.com/wireguard-tools/about/src/man/wg-quick.8)
   which is included with the main wireguard-tools distribution.
 * [NetworkManager](https://www.xmodulo.com/wireguard-vpn-network-manager-gui.html)
   which includes a GUI style configuration.

Alternatively, this repository includes its own script
[vpn.sh](vpn.sh) which is a simple Bash script that invokes the `wg`
and `ip` commands directly, requiring no further dependencies. This
script is designed for the use case where you want to route ALL
non-local traffic through the VPN, for the typical privacy enhancement
use case.

Simply copy the settings from your peer config into the variables at
the top of the script ([vpn.sh](vpn.sh)) and run:

```
./vpn.sh up
```

To bring the connection back down again, run:

```
./vpn.sh down
```

This script was written according to the ["The Classic Solutions:
Improved Rule-based
Routing"](https://www.wireguard.com/netns/#the-classic-solutions)
guide/section from wireguard.com, which it is documented that this
loosly follows the same thing that
[wg-quick](https://git.zx2c4.com/wireguard-tools/about/src/man/wg-quick.8)
does, just in a more transparent fashion. The wireguard.com guide
shows an even cooler, superior method, using network namespaces, and
they included a script for that method. It is slightly more complex
than the "classic solution", and their script does not appear to be
compatible with tools like NetworkManager, so [vpn.sh](vpn.sh) has not
yet attempted to implement the namespace method.
