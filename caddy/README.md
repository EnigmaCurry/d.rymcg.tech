# Caddy

[Caddy](https://github.com/caddyserver/caddy) is an HTTP server with
automatic TLS support via Lets Encrypt. This config is deployed behind
[Traefik](../traefik) through a route that enables TLS passthrough, so
that TLS termination is handled entirely by Caddy.

Although Caddy can be used to serve static files, similar to
[nginx](../nginx), it can also be used as a simple TLS certificate
resolver/updater to be used by some other (non HTTP) service. The
certificate and key can be accessed by sharing the `caddy_caddy_data`
volume. (See commented out `my-sidecar` example in
[docker-compose.yaml](docker-compose.yaml))

## Config

```
make config
```

## Install

```
make install
```

## Add static files to the volume

HTML and other files that you want to serve are to be stored in the
volume `caddy_caddy_html` (or `${INSTANCE}_caddy_html` for an instance
other than the default.) You may setup the [sftp](../sftp) service for
easy access to the volume.
