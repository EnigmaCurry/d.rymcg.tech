# qbittorrent

This config is for the [qBittorrent](https://www.qbittorrent.org/)
Bittorrent client.

## Setup

### Consider installing WireGuard first

If you don't want to use bittorrent over your native ISP, you may want
to consider installing [WireGuard](../wireguard) first. Then you can
tell qBittorrent to use the VPN for all of its traffic.

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
 * `QBITTORRENT_IP_SOURCE_RANGE` - the IP whitelist of clients
   allowed to connect to the qbittorrent client webapp (Traefik
   enforced). If you want to only rely upon passwords, but allow every
   IP address to connect, enter `0.0.0.0/0`. Otherwise you should
   prevent access except from a specific range of IP addresses, eg.
   `192.168.1.1/24`.

All these client credentials are stored in your `.env` file.

### Authentication and Authorization

In order to prevent unauthorized access, it is **highly recommended**
to enable sentry auth. 

See [AUTH.md](../AUTH.md) for information on adding external
authentication on top of your app.

### qBittorrent config options
Once up and running, you can configure qBittorrent in its web UI, but
qBittorrent's configs are reset on each startup of the Docker container.
So we set them in environment variables, so they can be reapplied on each
startup. 

The qBittorrent configurations are not included in `make config` - you'll
need to manually edit your `.env` file to adjust them.

To know what the settings are, you might want to install qBittorrent
first, and set the variable via the web UI, and then copy whatever
values it puts into `/var/lib/docker/volumes/<container's volume
name>/_data/qBittorrent/qBittorrent.conf` (on the host) and paste it
your `.env` file to make it permanent.

In your `.env` file, the lines in \[brackets\] are simply qBittorrent
configuration categories, for your reference.

If you add any additional qBittorrent configs to your `.env` file, you'll also
need to add them to `docker-compose.yaml` and
`qbittorrent-config/template/qBittorrent.conf`. You can follow the examples
already in those files for formatting and naming conventions.

If you change or add any qBittorrent config values, run `make install`.

## Deploy

Once configured, deploy it:

```
make install
```

```
make open
```

## Verify the VPN is functional

The [wireguard service does not have an integrated
killswitch](https://github.com/linuxserver/docker-wireguard/issues/139) -
if for any reason wireguard fails to start, including for reasons of
misconfiguration and/or host incompatibilities, then qbittorrent will
*NOT* be protected, and will be using the local internet connection
instead of the VPN.

Before using the service, you should verify that your VPN is working:

```
# Check that both wireguard and qbittorent are running (two containers:)
make status

# Check the logs, make sure there isn't an error:
make logs

# Exec into the qbittorrent container and check the ip address being used:
# (This should report your VPN connection details, not your local connection)
make shell
curl ifconfig.co/json
```

## Issues with IPv6

On arm64 I had an issue with ipv6 with this error reported from wireguard:

```
qbittorrent-wireguard-wireguard-1    | [#] ip6tables-restore -n
qbittorrent-wireguard-wireguard-1    | modprobe: can't load module ip6_tables (kernel/net/ipv6/netfilter/ip6_tables.ko.zst): invalid module formatqbittorrent-wireguard-wireguard-1    | ip6tables-restore v1.8.8 (legacy): ip6tables-restore: unable to initialize table 'raw'
```

This may have been a host issue, but I was able to work around it by simply removing ipv6 support in the configuration.

```
## To disable ipv6 In your .env file:

# Don't set an ipv6 address:
QBITTORRENT_VPN_CLIENT_INTERFACE_IPV6=
# Remove the ::0/0 from the QBITTORRENT_VPN_CLIENT_PEER_ALLOWED_IPS list:
QBITTORRENT_VPN_CLIENT_PEER_ALLOWED_IPS=0.0.0.0/0
```
