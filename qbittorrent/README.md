# qBittorrent

[qBittorrent](https://www.qbittorrent.org/) is a Bittorrent client.

## Setup

### Consider installing WireGuard first

If you don't want to use qBittorrent over your native ISP connection,
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
   enforced). If you want to only rely upon passwords but allow every
   IP address to connect, enter `0.0.0.0/0`. Otherwise you should
   prevent access except from a specific range of IP addresses, eg.
   `192.168.1.1/24`.

When asked to choose the network mode, you have two choices:

 * Use the `default` container network. This will use your native ISP
   connection.
 * Use the container network of a WireGuard instance. This will route
   all traffic through a VPN.

### Admin credentials

The default credentials for the web UI are "admin" with the password
"adminadmin", but the default configurations also bypass the login
when accessing qBittorrent's web UI from the container's localhost and
from any IP address (there are 2 different configurations that allow
bypass, and they're both enabled by default). So on initial install,
you won't be prompted to log in.

You change the admin username in your
`env_{DOCKER_CONTEXT}_{INSTANCE}` file, but the password is stored
encoded so you can't just type it directly into
`env_{DOCKER_CONTEXT}_{INSTANCE}`. To change the admin password and
make it persist for future installs:

 1) Install qBittorrent with default configurations.
 2) Change the admin password in the web UI (Options -> WebUI ->
 Authentication).
 3) Examine the contents of `/var/lib/docker/volumes/<container's
volume name>/_data/qBittorrent/qBittorrent.conf` (on the host) and
copy the value of the `WebUI\Password_PBKDF2` variable (including the
quotation marks, e.g.,
`"@ByteArray(OEeeMtO0Qkfvg1mRHOygfA==:z8blJXS2SjA6jrccbnqF8jqnt4ACGBaQ1chFcvVyIOnP7aK0tk5yN3v/RrQFXf47y9ZqVrOta8fshzr7h65Yow==)"`).
 4) Paste that in your `env_{DOCKER_CONTEXT}_{INSTANCE}` file as the
 value for the `QBITTORRENT_WebUIPassword_PBKDF2` variable.
 5) Run `make install`.

In order to be prompted to log in, you'll need to disable the "Bypass
authentication for clients on localhost" and "Bypass authentication
for clients in whitelisted IP subnets" configurations. To disable them
and make it persist for future installs:

 1) Edit your `env_{DOCKER_CONTEXT}_{INSTANCE}` file:
    - Change `QBITTORRENT_WebUIAuthSubnetWhitelistEnabled` to false.
    - Change `QBITTORRENT_WebUILocalHostAuth` to true.
 2) Run `make install`.

### Categories

qBittorrent allows you to create categories to manage your torrents.
To make categories that persist:

 1) Copy `qbittorrent-config/categories-dist.json` into
`qbittorrent-config/categories_{DOCKER_CONTEXT}_{INSTANCE}.json`
    - An easy way to do this is to run `make copy-categories`
 2) Customize it with your own categories.
 3) Run `make install`.

### Authentication and Authorization

In order to prevent unauthorized access, it is **highly recommended**
to enable sentry auth. 

See [AUTH.md](../AUTH.md) for information on adding external
authentication on top of your app.

### qBittorrent config options

Once up and running, you can configure qBittorrent in its web UI, but
qBittorrent's configs are reset on each startup of the Docker
container. So we set them in environment variables, so they can be
reapplied on each startup.

The qBittorrent configurations are not included in `make config` -
you'll need to manually edit your `.env_{DOCKER_CONTEXT}_{INSTANCE}`
file to adjust them.

To know what the settings are, you might want to install qBittorrent
first and set the variable via the web UI, and then copy whatever
values it puts into `/var/lib/docker/volumes/<container's volume
name>/_data/qBittorrent/qBittorrent.conf` (on the host) and paste it
your `.env_{DOCKER_CONTEXT}_{INSTANCE}` file to make it permanent.

In your `.env_{DOCKER_CONTEXT}_{INSTANCE}` file, the lines in
\[brackets\] are simply qBittorrent configuration categories, for your
reference.

If you add any additional qBittorrent configs to your
`.env_{DOCKER_CONTEXT}_{INSTANCE}` file, you'll also need to add them
to `docker-compose.yaml` and
`qbittorrent-config/template/qBittorrent.conf`. Follow the
examples already in those files for formatting and naming conventions.

If you change or add any qBittorrent config values, run `make install`.

## Install

```
make install
```

## Open

```
make open
```

## Destroy

```
make destroy
```

This completely removes the container and its volume.
