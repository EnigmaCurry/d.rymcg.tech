# Caddy

[Caddy](https://github.com/caddyserver/caddy) is an HTTP server with
automatic TLS support. By default, this config is deployed behind
[Traefik](../traefik) like every other d.rymcg.tech app: Traefik
terminates TLS, and Caddy serves plain HTTP. This means all of the
usual Traefik middlewares (IP filtering, HTTP Basic Auth, OAuth2,
mTLS) are available.

Optionally, you can enable the experimental TLS passthrough mode,
where Caddy manages its own certificate (see below).

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

## TLS modes

Choose the mode with `CADDY_TLS_MODE` (`make config` will ask):

 * `traefik` (default) - Traefik terminates TLS using its own
   certificate resolver, and proxies plain HTTP to Caddy on port 80.
   Caddy does not contact any ACME server.

 * `passthrough` (experimental) - Traefik routes the raw TLS stream
   (by SNI) straight through to Caddy on port 443, and Caddy obtains
   its own certificate from `CADDY_ACME_CA` (Let's Encrypt by
   default). This is useful for playing with Caddy's own TLS features
   (e.g., on-demand TLS, Caddy client auth). Limitations:
   * Only `CADDY_IP_SOURCERANGE` applies. HTTP Basic Auth, OAuth2, and
     mTLS settings are ignored, because Traefik never sees the HTTP
     traffic.
   * Caddy must be able to solve the ACME challenge itself
     (TLS-ALPN-01 via Traefik's passthrough), so the domain must be
     publicly reachable on port 443.
   * Caddy sees Traefik's IP as the client address.

### Getting a certificate for other (non-HTTP) services

The recommended approach is Traefik's `acme-sh` certificate resolver
(`TRAEFIK_ACME_SH_ENABLED=true`, see [TOUR.md](../TOUR.md)), which
supports DNS-01 challenges via acme-dns and writes certificates to the
`traefik_certs` volume.

In `passthrough` mode, Caddy's own certificate can also be shared with
other containers via the `caddy_caddy_data` volume. It is stored under
`/data/caddy/certificates/${CADDY_ACME_CA}-directory/${CADDY_TRAEFIK_HOST}/`
(see the commented out `my-sidecar` example in
[docker-compose.yaml](docker-compose.yaml)).
