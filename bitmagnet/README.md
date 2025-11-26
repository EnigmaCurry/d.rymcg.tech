# bitmagnet

[bitmagnet](https://github.com/bitmagnet-io/bitmagnet) is a
self-hosted BitTorrent indexer, DHT crawler, content classifier, and
torrent search engine with web UI, GraphQL API, and Servarr stack
integration. It is not reliant on any external trackers or torrent
indexers - it's self-contained, connected via
[DHT](https://bitmagnet.io/#dht-what-now) to a global network of peers
and constantly discovering new content.

## Config

```
make config
```

This will ask you to enter the domain name to use.
It automatically saves your responses into the configuration file
`.env_{DOCKER_CONTEXT}_{INSTANCE}`.

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

This completely removes the container and all its volumes.
