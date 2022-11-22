# TiddlyWiki

[TiddlyWiki](https://tiddlywiki.com/) is a non-linear notebook for
capturing, organising, and sharing complex information. TiddlyWiki
stores itself, and the entire wiki database, inside of a single
`.html` file. TiddlyWiki can save itself to many different storage
backends, but by default it uses WebDAV and pushes changes back to the
same server and path that it is served from.

This project configuration creates an [Nginx](https://nginx.org)
WebDAV server backend with
[bfren/docker-nginx-webdav](https://github.com/bfren/docker-nginx-webdav)
and serves only a single TiddlyWiki `index.html` file. TiddlyWiki
knows what to do when served in this environment, and it will
automatically save any changes made in the browser, and pushes a
modified `index.html` back to the server.

The default configuration is for a private notebook, protected with a
username/password, only viewable and editable by an admin account. You
can share the same URL and username/password amongst all trusted
editors (or create individual credentials for the same access
privilege). If you want to, you can enable optional public read-only
access as well (see `TIDDLYWIKI_PUBLIC_IP_SOURCERANGE`).

This project is
[instantiable](https://github.com/EnigmaCurry/d.rymcg.tech#creating-multiple-instances-of-a-service),
so you can create several separate wikis for different purposees, with
different access credentials.

## Config

```
make config
```

Configure the following environment variables:

 * `TIDDLYWIKI_TRAEFIK_HOST` the domain name to serve the wiki from.
 * Answer the questions to setup the admin usernames and passwords
   (this automatically sets `TIDDLYWIKI_ADMIN_HTTP_AUTH` with
   `htpasswd` encoded usernames/passwords).
 * Optionally enable public read-only access, and setup guest
   usernames/passwords.

Install:

```
make install
```

Open the wiki as the admin user:

```
make open
```

See the URL with the username and password printed in the terminal,
share this with your trusted friends and they will be able to edit the
same wiki.

## Authentication and Authorization

The Traefik configuration handles network IP address filtering and
user authentication:

Public read-only access:

 * **Public access is disabled by default**.
 * To enable public read-only access, you must set
 `TIDDLYWIKI_PUBLIC_IP_SOURCERANGE`. The default (`0.0.0.0/32`) turns
 off all public (unauthenticated) access. Set this to a specific
 subnet (or list of comma separated subnets) to allow only selected
 networks, eg: `192.168.1.1/24,10.10.0.0/16`. You can enable all
 public access with `0.0.0.0/0`.
 * Public read-only access is granted to all (IP filtered) requests on
   `https://${TIDDLYWIKI_TRAEFIK_HOST}/` (root path `/` via `HTTP GET`
   *only*)

Admin read-write access:
 * Admin read-write access is granted only via HTTP Basic
   Authentication on `https://${TIDDLYWIKI_TRAEFIK_HOST}/editor`.
 * There is no IP filtering applied by default
   (`TIDDLYWIKI_ADMIN_IP_SOURCERANGE=0.0.0.0/0`), the admin account can
   access from any IP address, using the password. You can filter
   subnets for the admin similarly to the public access.

## Using TiddlyWiki

Heres a few of the things I've learned using TiddlyWiki:

 * There are many plugins you may wish to install, which you can do
   from the `ControlPanel`:
    * Click the wheel icon to open `ControlPanel`
    * click `Plugins`
    * `Get more plugins`
    * `open plugin library`
 * Some cool plugins:
  * markdown
  * comments
  * blog
 * By default, the starting page only shows the `GettingsStarted`
   tiddler. Change the Default tiddlers to `[list[$:/StoryList]]` and
   you will see your most recently edited tiddlers instead.

