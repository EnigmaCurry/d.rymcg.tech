# Wireguard

This configuration is for a standalone
[Wireguard](https://www.wireguard.com/) VPN service (without
integration with Traefik Proxy).

## d.rymcg.tech provides *two different* wireguard configs

> [!NOTE] 
> This config is not to be confused with the other wireguard
> config that is [integrated with Traefik](../traefik/README.md#wireguard-vpn). 
> The one included with Traefik is a layer 7 (HTTP) proxy. On the other hand, 
> this config is used as a generic layer 4 (TCP/UDP) VPN service, which is lower
> level than the one integrated with Traefik. On the whole, this one
> is a much simpler configuration, but each one has specific
> tradeoffs.

Reasons you may wish to use this wireguard config:

 * If you want a **layer 4** (TCP/UDP) tunnel for privacy enhanced
   internet access and roaming (a typical consumer privacy shield,
   with SNAT IP masquerading). All of your internet traffic will
   appear to originate from your fixed public server IP address (not
   your home).
 * If you want to expose a **layer 4** private service (TCP/UDP),
   running behind a NAT firewall, to the public internet (DNAT port
   forwarding), using a public gateway (running on a droplet/VPS) as
   the go between. This does not require any opening of ports on the
   local router (only the public gateway server needs open ports).

Reasons you may wish to use the *other* [Traefik integrated
wireguard](../traefik/README.md#wireguard-vpn) instead of this one:

 * If you want to run a private **layer 7** (HTTP) service in the
   cloud, accessible from various locations, (eg. a company wide
   intranet service).
 * If you want to expose *select* **layer 7** (HTTP) applications
   (based on domain name), to the public internet, from a fixed
   location (eg. home or office), and you are capable of opening a
   public UDP port (eg. 51820) in each location's firewall.

## Config

Setup d.rymcg.tech on a public server (VPS) according to the main
[README.md](../README.md) (Note: you do not need to install Traefik on
the public VPS.)

Create a public DNS entry for your wireguard server (eg.
`wireguard.example.com`) pointing to the IP address of your Docker
host server.

From this directory, run:

```
make config     # This creates the .env_{CONTEXT} config file.
```

Answer the questions to enter the following required config settings:

 * `WIREGUARD_HOST` enter the fully qualified domain name you chose
   for this wireguard service (eg. `wireguard.example.com`).
 * `WIREGUARD_PEERS` enter the comma separated list of all the peer
   configs to create. Each peer name must be alphanumeric with **no**
   spaces, **no** dashes, **no** underscores. (eg.
   `myclient1,myclient2,myclient3`)

There are additional/optional configuration you can make in your
`.env_{CONTEXT}` file by hand, see the comments in
[.env-dist](.env-dist).

### Configure public peer ports (optional)

You may wish to run servers at home that typically are not accessible
from the internet. To do so, set `WIREGUARD_PUBLIC_PEER_PORTS` in your
.env file, and this will setup port forwarding (DNAT) through the VPN
tunnel. There is no need to open a port in your LAN router, and so it
should work from any random internet hotspot, or other networks
outside of your control.

For example, to open ports 443 and 53, running on two separate VPN
clients:

```
# Format is a comma separated list of 4-tuples: 
#         PEER_IP_ADDRESS:PEER_PORT:PUBLIC_PORT:PORT_TYPE,...
WIREGUARD_PUBLIC_PEER_PORTS=10.13.17.2:443:443:tcp,10.13.17.3:53:53:udp
```

For each peer that runs a server behind a NAT firewall, you must
enable the "keep alive" setting. This will ensure that the wireguard
connection stays available for incoming requests. Set
`WIREGUARD_PERSISTENTKEEPALIVE_PEERS`:

```
# Specify the list of peers to send a keep alive packets to:
# (eg 'all', or a comma separated list of peer names. Set blank to turn it off.)
WIREGUARD_PERSISTENTKEEPALIVE_PEERS=all
```

For more details, see the full comments in [.env-dist](.env-dist).

## Install

From this directory, run:

```
make install
```

## Show the generated peer config files:

From this directory, run:

```
make show-wireguard-peers    ## Prints ALL of the peer configs.
```

*All* of the peer config files will be printed to the screen in
sequence. Notice that they are each separated by a comment at the top
starting like `## /config/peer_myclient1/peer_myclient1.conf`.

If you want to setup mobile clients (android), you may instead wish to
see the QR encoded copy of the same information. Run:

```
make show-wireguard-peers-qr   ## Prints the QR code for every peer config.
```

## Linux client script

There are many different wireguard clients you can choose from,
including:

 * [wg-quick](https://git.zx2c4.com/wireguard-tools/about/src/man/wg-quick.8)
   which is included with the main wireguard-tools distribution.
 * [NetworkManager](https://www.xmodulo.com/wireguard-vpn-network-manager-gui.html)
   which includes a GUI style configuration.

Alternatively, this repository includes its own script
[vpn.sh](vpn.sh) which is a simple Bash script that invokes the `wg`
and `ip` commands directly, requiring no further dependencies. This
script is designed for the use case where you want to route ALL
non-local (non-LAN) traffic, of the entire machine, through the VPN,
which is typical of consumer privacy shields.

Simply copy the settings from your peer config (`make
show-wireguard-peers`) into the variables at the top of the script
([vpn.sh](vpn.sh)) and then run the script to start the VPN:

```
./vpn.sh up
```

To bring the connection back down again, run:

```
./vpn.sh down
```

This script was written according to ["The Classic Solutions: Improved
Rule-based
Routing"](https://www.wireguard.com/netns/#the-classic-solutions) from
wireguard.com, which it is documented that this loosly follows the
same thing that
[wg-quick](https://git.zx2c4.com/wireguard-tools/about/src/man/wg-quick.8)
does, just in a more transparent fashion. The wireguard.com guide
shows an even cooler, superior method, using network namespaces, and
they included a script for that method. It is slightly more complex
than this "classic solution", and their script does not appear to be
compatible with tools like NetworkManager, so [vpn.sh](vpn.sh) has not
yet attempted to implement the namespace method.
