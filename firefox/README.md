# Firefox

This runs
[linuxserver/docker-firefox](https://github.com/linuxserver/docker-firefox),
which is the Firefox web browser embedded in a web page.

## Setup

### Consider installing WireGuard first

If you don't want Firefox to use your native ISP connection for
outgoing requests, you may want to consider installing
[WireGuard](../wireguard) first. Then you can tell Firefox to use the
VPN for all of its traffic.

### Config

```
make config
```

There are many options not exposed by the interactive config script.
See the upstream
[linuxserver/docker-firefox](https://github.com/linuxserver/docker-firefox)
docs, and edit your `.env_{CONTEXT}_{INSTANCE}` file.

#### Authentication and Authorization

*Important!* You need to enable some kind of sentry authorization in
front of this service to prevent unauthorized access!

See [AUTH.md](../AUTH.md) for information on adding
external authentication on top of your app.

## Install

```
make install
```

## Open

```
make open
```
