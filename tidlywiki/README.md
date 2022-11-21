# TiddlyWiki

[TiddlyWiki](https://tiddlywiki.com/) is a non-linear notebook for
capturing, organising, and sharing complex information. TiddlyWiki
stores itself and the entire wiki database inside of a single .html
file. TiddlyWiki can save itself to many different storage backends,
but by default it uses WebDAV.

This project configuration creates an [Nginx](https://nginx.org)
WebDAV server backend with
[bfren/docker-nginx](https://github.com/bfren/docker-nginx) and serves
the TiddlyWiki `index.html` file. TiddlyWiki knows what to do when
served in this environment, and it will automatically save changes
made in the browser back to itself, and replaces the server's
`index.html` with the modified version.

## Config

```
make config
```

Configure the following environemnt variables:

 * `TIDLYWIKI_TRAEFIK_HOST` the domain name to serve the wiki from.
 * Setup usernames and passwords (this automatically sets
   `TIDLYWIKI_HTTP_AUTH` with `htpasswd` encoded usernames/passwords).

```
make install
```

```
make open
```

## Authentication and Authorization

The Traefik configuration handles user authentication and network IP
address filtering:

 * Public read-only access is granted to all (IP filtered) requests on
   `https://${TIDLYWIKI_TRAEFIK_HOST}/` (root path `/` via `HTTP GET`
   *only*)
 * Admin read-write access is granted only via HTTP Basic
   Authentication on `https://${TIDLYWIKI_TRAEFIK_HOST}/admin`
 * Filtering on IP address sourcerange by setting
   `TIDLYWIKI_IP_SOURCERANGE`. The default (`0.0.0.0/0`) allows
   connecting from any client IP address. Set this to a specific
   subnet (or list of comma separated subnets) to allow only selected
   networks, eg: `192.168.1.1/24,10.10.0.0/16`. Disable all traffic
   with `0.0.0.0/32`.
