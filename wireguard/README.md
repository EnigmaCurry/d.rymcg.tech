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
> is much simpler to configure, but each one has specific
> tradeoffs.

Reasons you may wish to use this wireguard config:

 * If you want a **layer 4** (TCP/UDP) tunnel for privacy enhanced
   internet access with roaming capability (eg. a typical consumer
   privacy shield, with SNAT IP masquerading). All of your internet
   traffic will appear to originate from your fixed public server IP
   address (not your local router's).
 * If you want to expose a **layer 4** private service (TCP/UDP),
   running behind a NAT firewall, to the public internet (DNAT port
   forwarding), using a public gateway (running on a droplet/VPS) as
   the go between. This does not require any opening of ports on the
   local router (only the public gateway server needs open ports).
 * You want optional IPv6 support.

Reasons you may wish to use the *other* [Traefik integrated
wireguard](../traefik/README.md#wireguard-vpn) instead of this one:

 * If you want to run a private **layer 7** (HTTP) service in the
   cloud, accessible from various locations, (eg. a company wide
   intranet service).
 * If you want to expose *select* **layer 7** (HTTP) applications
   (routed based on domain name), to the public internet, from a fixed
   location (eg. home or office), and you are capable of opening a
   public UDP port (eg. 51820) in each location's firewall.

## Config

 * Setup d.rymcg.tech on a public server (VPS) according to the main
[README.md](../README.md) (Note: you do not need to install Traefik on
the public VPS.)

 * Create a public DNS entry for your wireguard server (eg.
`wireguard.example.com`) pointing to the IP address of your Docker
host server.

Next, from this directory, run:

```
make config     # This creates the .env_{CONTEXT} config file.
```

Answer the questions to enter the following required config settings:

 * `WIREGUARD_HOST` - Enter the fully qualified domain name you chose
   for this wireguard service (eg. `wireguard.example.com`).
 * `WIREGUARD_PEERS` - Enter the comma separated list of all the peer
   configs to create. Each peer name must be alphanumeric with **no**
   spaces, **no** dashes, **no** underscores. (eg.
   `myclient1,myclient2,myclient3`)

There are additional variables in the `.env_{CONTEXT}` file you may
wish to edit by hand, see the comments in [.env-dist](.env-dist).

### Configure public peer ports (optional)

You may wish to run public services at home, which typically are not
accessible from the internet. To expose these services to the world,
set `WIREGUARD_PUBLIC_PEER_PORTS` in your .env file, and this will
setup port forwarding (DNAT) through the VPN tunnel. There is no need
to open any port in your LAN router, and so it should work from any
random internet hotspot, or most other networks outside of your
control.

For example, to open ports `443` and `53` publicly, running on two
separate VPN clients:

```
# Format is a comma separated list of 4-tuples: 
#         PEER_IP_ADDRESS-PEER_PORT-PUBLIC_PORT-PORT_TYPE,...
WIREGUARD_PUBLIC_PEER_PORTS=10.13.17.2-443-443-tcp,10.13.17.3-53-53-udp
```

> [!NOTE] 
> The 4-tuple port mapping is separated with dashes `-` not the traditional colon
> `:` because that is reserved for IPv6 addresses. If you want create a public peer port for an IPv6 address it would be like `WIREGUARD_PUBLIC_PEER_PORTS=fd8c:8ac3:9074:5183::2-443-443-tcp`

For each peer that runs a server behind a NAT firewall, you must
enable the "keep alive" setting. This will ensure that the wireguard
connection stays available for incoming requests. Set
`WIREGUARD_PERSISTENTKEEPALIVE_PEERS`:

```
# Specify the list of peers to send keep alive packets to:
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
 * [vpn.sh](vpn.sh) included in this repository as our own custom
   script for this config.

### vpn.sh

This repository includes its own script [vpn.sh](vpn.sh) which is a
simple Bash script that invokes the `wg` and `ip` commands directly,
requiring no further dependencies.

Client requirements:

 * Any Linux machine, native or virtual, with `root` access or any
   account with `sudo` privileges. (No Docker required!)
 * Install all dependent packages: `bash`, `iproute2`,
   `wireguard-tools`.
 
   * Arch: `pacman -S bash iproute2 wireguard-tools`
   * Debian/Ubuntu: `apt install bash iproute2 wireguard-tools`
   * Fedora: `dnf install bash iproute wireguard-tools`

Download the script:

```
curl -O https://raw.githubusercontent.com/EnigmaCurry/d.rymcg.tech/master/wireguard/vpn.sh
```

Simply copy all of the settings shown from your peer config (`make
show-wireguard-peers`) into the variables at the top of the script
([vpn.sh](vpn.sh)) and then run the script to start the VPN:

```
chmod +x vpn.sh
./vpn.sh up
```

To bring the connection back down again, run:

```
./vpn.sh down
```

Test that the connection behaves correctly using tools like `ping`,
`tracepath` (or `traceroute`), and external IP finding tools like
`curl ifconfig.me`. Now that you know it works, continue reading to
learn about how to enable the systemd service, so that it starts
automatically on boot.

### History

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
each of these peers (which includes the unique wireguard keys required
for each client to connect).

Run `make show-wireguard-peers`. It will print the config for all
three peers `archdev`, `bob`, and `mary`. 

Let's consider only the first one, `archdev`. Here is an example
output for the config file for `archdev`:

```
## Example output of `make show-wireguard-peers` ...

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
shown in the peer config (make sure you change`WG_ADDRESS`, `WG_PRIVATE_KEY`,
`WG_PEER_PUBLIC_KEY`, `WG_PEER_PRESHARED_KEY`, and `WG_PEER_ENDPOINT`,
your actual values WILL BE DIFFERENT, all of the other settings can
probably be left alone.):

```
## An Excerpt from the vpn.sh script (near the top of the file)
## You'll need to change at least these four variables according to your config:
WG_ADDRESS=10.13.17.2
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
`WG_PEER_ALLOWED_IPS` in the script.

By default, this value is set to
`WG_PEER_ALLOWED_IPS=0.0.0.0/0,::0/0`, which means that ALL non-local
(non-LAN) traffic (both ipv4 and ipv6) will go over the VPN. That's
usually what you want for a typical consumer privacy shield.

If you have more advanced use cases, you can customize it. For
example, if you have two subnets you want to go over the VPN, but
everything else you want to go over the normal connection, set it like
this (comma separated [CIDR
notation](https://en.wikipedia.org/wiki/CIDR#CIDR_notation)):
`WG_PEER_ALLOWED_IPS=10.13.17.0/24,192.168.100.0/24`. Every network
range that is listed in this list will go over the VPN, and
conversely, everything *NOT* in that list will go over your normal
internet connection.

You can use a tool like
[tracepath](https://man.archlinux.org/man/tracepath.8) to confirm
which route a particular connection will take.

### Client DNS setting

[vpn.sh](vpn.sh) automatically manages your system `/etc/resolv.conf`
by default, configurable by the following environment variables:

 * `WG_USE_VPN_DNS=true` (default) - `true` means create a new
   `/etc/resolv.con` file using the `WG_DNS` nameserver value. `false`
   means don't touch `/etc/resolv.conf`, leaving whatever setting is
   already there.
 * `WG_DNS=10.13.17.1` (default) - set this to your preferred DNS
   resolver address.
 
The default values are setup for preventing DNS leaks, forcing all
system level DNS queries to go to the wireguard server directly. (in
this case, a "leak" would be where the DNS was allowed to go to your
local LAN resolver, instead of through the VPN. The default values
prevent this.) Please be advised that not all applications will honor
`/etc/resolv.conf`, and may use their own settings (especially
browsers with a DNS-over-HTTP privacy setting.)

If you do not want `vpn.sh` to touch your `/etc/resolv.conf`, set
`WG_USE_VPN_DNS=false`.

> ![Note] 
> When you run `./vpn.sh up`, with the setting `WG_USE_VPN_DNS=true`,
> the script will copy the original (ie. non-vpn) `/etc/resolv.conf` to
> `/tmp/vpn.sh.non-vpn-resolv.conf` as a backup, and then creates a new
> `/etc/resolv.conf` that forces the use of the `WG_DNS` nameserver
> address. This is so that when you run `./vpn.sh down` it can restore
> the original `/etc/resolv.conf`. It is important that this occurs
> *before* system reboots, otherwise the wrong file will be in place on
> next boot. Therefore, it is recommended to use the systemd service,
> which takes care of this step for you.

### Systemd service (start on boot)

When you run `./vpn.sh up`, it only sets up the VPN temporarily. If
you reboot the machine, the VPN will no longer be running. You can
install a [systemd](https://wiki.archlinux.org/title/Systemd) service
in order to automatically start the VPN every time you start your
computer.

To create the systemd service, run:

```
./vpn.sh systemd-enable
```

This will create a systemd unit file at
`/etc/systemd/service/vpn.service`.

You can now manage the VPN as any other systemd service.

To view the status, run:

```
systemctl status vpn
```

To view the logs, run:

```
journalctl -u vpn
```

To disable the VPN, run:

```
systemctl disable --now vpn
```

To re-enable the VPN, run:

```
systemctl enable --now vpn
```

With the service enabled, the service will start automatically on
every system boot.

To completely remove the systemd service:

```
./vpn.sh systemd-disable

## Or simply delete /etc/systemd/system/vpn.service
```

> [!NOTE]
> The entire configuration for the VPN still lives inside vpn.sh. The
> systemd unit file (/etc/systemd/system/vpn.service) points to the
> original location of vpn.sh. Once installed, you should not move nor
> delete the script!

## Destroy VPN and all credentials

The server and client keys are stored in the volume of the wireguard
container on the server. If you want to delete them all, you can
simply destroy the container volume:


```
# Remove the wireguard server, volume, and ALL of the wireguard keys:
make destroy
```

To recreate the wireguard server, and issue NEW keys to all clients, simply
reinstall:

```
## Since the wireguard volume does not exist anymore, it will be recreated, creating new keys:
make install
```

## IPv6 (optional)

The container image
([linuxserver/docker-wireguard](https://github.com/linuxserver/docker-wireguard))
that this config is based upon [does not officially support
IPv6](https://github.com/linuxserver/docker-wireguard/pull/183#issuecomment-1273242895),
however, this configuration has been modified to make it work.

### Prepare the Docker host for IPv6

There are a few requirements in order to get IPv6 to work:

 * The host platform that you run your wireguard server on must
natively support IPv6. 
 * You must configure the Docker daemon to enable IPv6.

For example, if you are using DigitalOcean to run your Docker server,
consult the [DigitalOcean documentation for enabling
IPv6](https://docs.digitalocean.com/products/networking/ipv6/how-to/enable/#on-existing-droplets)
(hint: enable IPv6 *before* you create the droplet).

You also must edit the Docker daemon configuration file to enable
IPv6, because as of Docker 25 it is still not enabled in the default
configuration. [Consult the Docker documentation for
details](https://docs.docker.com/config/daemon/ipv6/).

On your Docker server, as root, edit the file
`/etc/docker/daemon.json`. This file does not exist by default, so if
it doesn't exist, you must create it. Enter the following into the
(new) file:

```
{
  "experimental": true,
  "ip6tables": true
}
```

Restart Docker, (or just reboot your server):

```
sudo systemctl restart docker
```

### Configure IPv6 for the wireguard server

You must edit the `.env_{CONTEXT}` file (created after `make config`),
and change the following variables for IPv6:

 * `WIREGUARD_IPV6_ENABLE=true` - this is the setting that controls
   whether or not you wish to enable IPv6 at all. By default, it is
   set to `false`, disabling the feature entirely.
   
 * `WIREGUARD_SUBNET_IPV6` - this is the IPv6 subnet to use for your
   peers (analagous to the the `WIREGUARD_SUBNET` setting used for
   IPv4). The subnet you choose should be in the dedicated private
   range starting with `fd`. This setting should NOT be in CIDR
   notation, instead it should simply end in a single digit `0` to
   indicate the start of the range and each new client will increment
   this digit by one. You can [generate a random subnet on this
   page](https://simpledns.plus/private-ipv6) (or just use the one
   provided in the default config, if it doesn't conflict for you).

 * `WIREGUARD_ALLOWEDIPS` - this is the list of IP ranges that are
   allowed to be trafficked on the VPN. It can contain both IPv4 and
   IPv6 ranges. By default, the value is `0.0.0.0/0,::0/0` meaning ALL
   ipv4 and ALL ipv6 address are allowed. Make sure the ranges you
   pick are set in [CIDR
   notation](https://en.wikipedia.org/wiki/CIDR#CIDR_notation),
   separated by commas to specify multiple ranges.

 * `WIREGAURD_PUBLIC_PEER_PORTS` - if you want to make your private
   services public, you can add the port mapping to the list in
   `WIREGAURD_PUBLIC_PEER_PORTS`. It accepts both IPv4 and IPv6
   addresses. Because of this, each port mapping uses the `-`
   character rather than the traditional `:` character (since `:` is
   used in IPv6 addresses). For example, if you wanted to open port
   443 on both IPv4 and IPv6, you could use the following example:
   `WIREGAURD_PUBLIC_PEER_PORTS=10.13.17.2-443-443-tcp,fd5c:d2af:a2c6:7d61::2-443-443-tcp`

 * `WIREGUARD_IPV6_DOCKER_SUBNET` - this is the subnet used for the
   Docker container networking interfacing with the host. It should
   NOT be the same subnet as `WIREGUARD_SUBNET_IPV6`. Choose a unique
   subnet by [generating another random
   subnet](https://simpledns.plus/private-ipv6) (or just use the
   default one provided).
   
Check the comments in [.env-dist](.env-dist) for more details.

### Configure IPv6 for the vpn.sh script

Configuring the [vpn.sh](vpn.sh) script should be straight forward,
you just copy the information directly from the values provided by
`make show-wireguard-peers`. Here is a brief description of the config
as it relates to IPv6:

 * `WG_ADDRESS` is a list of the IP addresses to assign to the client `wg0` network interface. By default you will have an IPv4 address only. But if the wireguard server has IPv6 enabled, you will have both listed, eg. `WG_ADDRESS=10.13.17.2,fd5c:d2af:a2c6:7d61::2`
 
 * `WG_PEER_ALLOWED_IPS` is a list of the allowed network ranges, both
   IPv4 and IPv6, exactly like the `WIREGUARD_ALLOWEDIPS` setting for
   the server. eg. `WG_PEER_ALLOWED_IPS=0.0.0.0/0,::0/0`.

