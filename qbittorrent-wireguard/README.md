# qbittorrent-wireguard

This is the [qBittorrent](https://https://www.qbittorrent.org/) Bittorrent
client combined with the [Wireguard](https://www.wireguard.com/) VPN
service. Connect wireguard to your VPN provider and anonymize your
peer connections.

## Setup

### Gather VPN provider config

Your VPN provider must support Wireguard. 

For example, Mullvad has a [Wireguard Config
Generator](https://mullvad.net/en/account/#/wireguard-config). This
will generate a wireguard config file containing all of the
information you need:

```
### Example wireguard config file from Mullvad:
### The PrivateKey and PublicKey have been redacted:
[Interface]
PrivateKey = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=
Address = 10.65.244.198/32,fc00:bbbb:bbbb:bb01::2:f4c5/128
DNS = 10.64.0.1

[Peer]
PublicKey = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=
AllowedIPs = 0.0.0.0/0,::0/0
Endpoint = 103.231.88.2:51820
```

### Config

Run `make config` 

Enter the following information as prompted:

 * `QBITTORRENT_TRAEFIK_HOST` - the domain name for the qbittorrent
   client interface (eg. `qbittorrent.example.com`)
 * `QBITTORRENT_PEER_PORT` - the random public port that is assigned
   by your VPN provider (optional, but helps you seed better. If not
   available, just use the default port suggested).
 * `QBITTORRENT_DOWNLOAD_VOLUME` - the name of the Docker volume or
   bind-mounted Host path, to store downloads (eg.
   `/storage/downloads`, this is a rare case where having a
   bind-mounted host path is most likely preferred over a regular
   Docker volume, so that you can easily access your downloads. Make
   sure to create the directory before install)
 * `QBITTORRENT_VPN_CLIENT_INTERFACE_PRIVATE_KEY` - the `PrivateKey`
   value from your VPN provided config file. (Long text ending with
   `=`)
 * `QBITTORRENT_VPN_CLIENT_INTERFACE_IPV4` and
   `QBITTORRENT_VPN_CLIENT_INTERFACE_IPV6` - the interface `Address`
   values from your VPN provided config file for both IPv4 and IPv6
   (the wireguard config could list be multiple addresses separated by
   a comma, eg. `10.65.244.198/32,fc00:bbbb:bbbb:bb01::2:f4c5/128`, in
   this example the first is the IPv4 address, the second is the IPv6.
   Don't enter the `/32` or `/128` part, just the part before it).
 * `QBITTORRENT_VPN_CLIENT_INTERFACE_PEER_DNS` the interface `DNS`
   value from your VPN provided config file eg `10.64.0.1`.
 * `QBITTORRENT_VPN_CLIENT_PEER_PUBLIC_KEY` - the peer `PublicKey`
   value from your VPN provided config file (Long text ending with
   `=`)
 * `QBITTORRENT_VPN_CLIENT_PEER_ENDPOINT` - the peer `Endpoint`
   value, which is the VPN provider's host address and port, eg
   `94.198.42.114:51820`
 * `QBITTORRENT_IP_SOURCE_RANGE` - the IP whitelist of clients
   allowed to connect to the qbittorrent client webapp (Traefik
   enforced). If you want to only rely upon passwords, but allow every
   IP address to connect, enter `0.0.0.0/0`. Otherwise you should
   prevent access except from a specific range of IP addresses, eg.
   `192.168.1.1/24`.
 * Enter the required HTTP Basic authentication username and passwords
   (Traefik enforced). This can be optionally saved to
   `passwords.json` so that `make open` works without a password.

All these client credentials are stored in your `.env` file.

#### qBittorrent config options
Once up and running, you can configure qBittorrent in its web UI, but
qBittorrent's configs are reset on each startup of the Docker container.
So we set them in environment variables on each startup. 

The qBittorrent configurations are not include in `make config` - you'll
need to manually edit your `.env` file to adjust them.

You might need to install qBittorrent and set the variable in the its web
UI, then copy the value from
`/var/lib/docker/volumes/<container's volume name>/qBittorrent/_data/qBittorrent/qBittorrent.conf`
(on the host) and paste it your `.env` file. 

You can set other qBittorrent configurations not already in your `.env` file
by adding the configuration's name from qBittorrent.conf. E.g., to set the
qBittorrent config "Connection\UPnP", add "QBITTORRENT_ConnectionUPnP=" to
your `.env` file, followed by whatever value you want to set. Notice that you
should preceed the qBittorrent config name with "QBITTORRENT_" and remove
all "\\" from the config name.

In your `.env` file, the lines in \[brackets\] are simply qBittorrent
configuration categories, for your reference.

If you change any qBittorrent config values, run `make install`.


Other settings that are not configured by `make config` and you should
use the default:

 * `QBITTORRENT_VPN_CLIENT_PEER_ALLOWED_IPS` - This should be the
   wireguard peer `AllowedIPs` value, that lists the address ranges
   that the client should use the VPN for. This should almost always
   be set to `0.0.0.0/0,::0/0` (ipv4,ipv6). This ensures that *all*
   traffic from the qbittorrent container goes through the VPN
   (except for the client interface which is exposed by Traefik, and
   protected by username/password or IP filter). You can modify this
   to access certain peers that dont' need a VPN (eg. on your LAN).

# Deploy

Once configured, deploy it:

```
make install
```

```
make open
```
