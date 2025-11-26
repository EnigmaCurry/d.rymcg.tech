# Webtop

[Webtop](https://docs.linuxserver.io/images/docker-webtop/) is a
containerized Linux Desktop accessible in your web browser.

## Setup

### Consider installing WireGuard first

If you don't want Webtop to use your native ISP connection for
outgoing requests, you may want to consider installing
[WireGuard](../wireguard) first. Then you can tell Webtop to use the
VPN for all of its traffic.

### Config

```
make config
```

There are many options not exposed by the interactive config script.
See the upstream
[linuxserver/docker-webtop](https://github.com/linuxserver/docker-webtop)
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
