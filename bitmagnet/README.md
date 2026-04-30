# bitmagnet

[bitmagnet](https://github.com/bitmagnet-io/bitmagnet) is a
self-hosted BitTorrent indexer, DHT crawler, content classifier, and
torrent search engine with web UI, GraphQL API, and Servarr stack
integration. It is not reliant on any external trackers or torrent
indexers - it's self-contained, connected via
[DHT](https://bitmagnet.io/#dht-what-now) to a global network of peers
and constantly discovering new content.

## WireGuard VPN Integration

Bitmagnet is designed to route all traffic through a WireGuard VPN
for privacy. During `make config`, you will be prompted to select a
WireGuard instance to use as the default gateway.

### Prerequisites

The [../wireguard](../wireguard) service must be set up and running
before installing bitmagnet. Follow the WireGuard setup instructions
first to create a VPN instance.

### How It Works

When configured with a WireGuard instance:
- All BitTorrent traffic is routed through the VPN
- The WebUI remains accessible via Traefik on the normal Docker network
- The container's default gateway is replaced with the WireGuard router

If you choose not to use a WireGuard instance, bitmagnet will use the
normal network (not recommended for privacy).

## Config

```
make config
```

This will ask you to enter the domain name to use.
It automatically saves your responses into the configuration file
`.env_{DOCKER_CONTEXT}_{INSTANCE}`.

### Database Storage

Bitmagnet accumulates a large amount of data (approximately 80GB per
1,000,000 torrents). During `make config`, you will be asked whether
to store the Postgres database in a Docker volume or a bind mount on
the host.

If you choose a bind mount, ensure the directory exists on the Docker
host and is owned by the UID:GID configured in your
`.env_{DOCKER_CONTEXT}_{INSTANCE}` file (`BITMAGNET_UID` and
`BITMAGNET_GID`, defaulting to `1000:1000`):

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external authentication on
top of your app.

## Install

```
make install
```

## Open

```
make open
```

This will automatically open the page in your web browser, and will
prefill the HTTP Basic Authentication password if you enabled it
(and chose to store it in `passwords.json`).

## Destroy

```
make destroy
```

This removes the containers and all Docker-managed volumes.

**If using a bind mount**, the database directory on the host is
**not** deleted. To completely reset the database, you must manually
delete the bind mount directory. Note that changing
`BITMAGNET_POSTGRES_PASSWORD` in your
`.env_{DOCKER_CONTEXT}_{INSTANCE}` file after initial setup will cause
authentication errors because the existing database was initialized
with the original password.
