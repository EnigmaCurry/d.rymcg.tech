# qbittorrent

This config is for the [qBittorrent](https://www.qbittorrent.org/)
Bittorrent client.

## Setup

### Consider installing WireGuard first

If you don't want to use BitTorrent over your native ISP connection,
you may want to consider installing [WireGuard](../wireguard) first.
Then you can tell qBittorrent to use the VPN for all of its traffic.

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

When asked to choose the network mode, you have two choices:

 * Use the `default` container network. This will use your native ISP
   connection.
 * Use the container network of a WireGuard instance. This will route
   all traffic through a VPN.

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
