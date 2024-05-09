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
   your local router's).
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
which is typical of consumer privacy shields. If you want configure it
so only *some* routes go over the VPN, while others remain on your
native connection, you can customize the `WG_PEER_ALLOWED_IPS`
variable (see the comments in [.env-dist](.env-dist) for details.)

Simply copy all of the settings shown from your peer config (`make
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

### Example script configuration

Suppose that when you ran `make config` you created three clients:
`archdev,bob,mary`.

In order to setup the clients, you need to view the configuration for
each of these peers (which includes the wireguard keys required to
connect).

Run `make show-wireguard-peers`. It will print the config for all
three peers `archdev`, `bob`, and `mary`. 

Let's consider only the first one, `archdev`. Here is an example
output for the config file for `archdev`, which is printed at the top
of the output of `make show-wireguard-peers`:

```
## /config/peer_archdev/peer_archdev.conf
[Interface]
Address = 10.13.17.2
PrivateKey = oNnzcPVu/iXpfxQQSS84U0vwdm4ODHJm2/gVONV10kU=
ListenPort = 51820
DNS = 10.13.17.1

[Peer]
PublicKey = vHH1QfTfX0exdowq4HkChUiwl5cVHSG35iDELm+vFno=
PresharedKey = IWJpkj8FeajeoqnRATnccNZAo+KZOwEPF8m0mRTHYUY=
Endpoint = wireguard.example.net:51820
AllowedIPs = 0.0.0.0/0,::0/0

### bob and mary configs follow after this, ignore them for now ....
```

Notice that the `archdev` config is annotated with the comment showing
the config file path inside the server wireguard container
(`/config/peer_archdev/peer_archdev.conf`), and the `bob` and `mary`
ones are printed after that.

Log into the client computer that `archdev` uses, and download the
[vpn.sh](vpn.sh) script onto that computer. Open the script in a text
editor, and you will need to copy the information shown from the peer
config into the variables at the top of the script. Here is what you
need to edit into the top part of that file, with the same values as
shown in the peer config (make sure you change `WG_PRIVATE_KEY`,
`WG_PEER_PUBLIC_KEY`, `WG_PEER_PRESHARED_KEY`, and `WG_PEER_ENDPOINT`,
your actual values WILL BE DIFFERENT, all of the other settings can
probably be left alone.):

```
## An Excerpt from the vpn.sh script (near the top of the file)
## You'll need to change at least these four variables:
WG_PRIVATE_KEY=oNnzcPVu/iXpfxQQSS84U0vwdm4ODHJm2/gVONV10kU=
WG_PEER_PUBLIC_KEY=vHH1QfTfX0exdowq4HkChUiwl5cVHSG35iDELm+vFno=
WG_PEER_PRESHARED_KEY=IWJpkj8FeajeoqnRATnccNZAo+KZOwEPF8m0mRTHYUY=
WG_PEER_ENDPOINT=wireguard.example.net:51820
```

In order to run the script, the user will need to be `root`, or at
least have [sudo](https://wiki.archlinux.org/title/Sudo) privileges.

Now that the file is edited, you can run it to start the VPN client:

```
## Make the script executable:
chmod a+x ./vpn.sh

## To start the VPN client:

./vpn.sh up

## To stop the VPN client:

./vpn.sh down
```

### Split routing

By default, the [vpn.sh](vpn.sh) client script is setup to force ALL
non-local (non-LAN) traffic over the VPN. If you want to make it so
only some traffic goes over the VPN, while the rest should go over
your normal connection, you can customize the variable called
`WG_PEER_ALLOWED_IPS` in the script (it does not matter how the server
is configured, it is the *client* that gets to decide this setting!)

By default, the value is set to `WG_PEER_ALLOWED_IPS=0.0.0.0/0,::0/0`,
which means that ALL non-local (non-LAN) traffic (both ipv4 and ipv6)
will go over the VPN. That's usually what you want for a typical
consumer privacy shield.

If you have more advanced use cases, you can customize it. For
example, if you have two subnets you want to go over the VPN, but
everything else to go over the normal connection, set it like this
(comma separated [CIDR
notation](https://en.wikipedia.org/wiki/CIDR#CIDR_notation))
`WG_PEER_ALLOWED_IPS=10.13.17.0/24,192.168.100.0/24`. Every network
range that is listed in this list will go over the VPN, and
conversely, everything *NOT* in that list will go over your normal
internet connection.


## Destroy VPN and all credentials

The server and client keys are stored in the volume of the wireguard
container on the server. If you want to delete them all, you can
simply destroy the container volume:


```
# Remove the wireguard server, volume, and ALL of the wireguard keys:
make destroy
```

To recreate the wireguard, and issue NEW keys to all clients, simply
reinstall:

```
## Since the wireguard volume does not exist anymore, it will be recreated, creating new keys:
make install
```
