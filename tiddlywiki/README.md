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
access as well (see `TIDLYWIKI_PUBLIC_IP_SOURCERANGE`).

This project is
[instantiable](https://github.com/EnigmaCurry/d.rymcg.tech#creating-multiple-instances-of-a-service),
so you can create several separate wikis for different purposees, with
different access credentials.

## Config

```
make config
```

Configure the following environment variables:

 * `TIDLYWIKI_TRAEFIK_HOST` the domain name to serve the wiki from.
 * Answer the questions to setup usernames and passwords (this
   automatically sets `TIDLYWIKI_HTTP_AUTH` with `htpasswd` encoded
   usernames/passwords).

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
 `TIDLYWIKI_PUBLIC_IP_SOURCERANGE`. The default (`0.0.0.0/32`) turns
 off all public (unauthenticated) access. Set this to a specific
 subnet (or list of comma separated subnets) to allow only selected
 networks, eg: `192.168.1.1/24,10.10.0.0/16`. You can enable all
 public access with `0.0.0.0/0`.
 * Public read-only access is granted to all (IP filtered) requests on
   `https://${TIDLYWIKI_TRAEFIK_HOST}/` (root path `/` via `HTTP GET`
   *only*)

Admin read-write access:
 * Admin read-write access is granted only via HTTP Basic
   Authentication on `https://${TIDLYWIKI_TRAEFIK_HOST}/admin`.
 * There is no IP filtering applied by default
   (`TIDLYWIKI_ADMIN_IP_SOURCERANGE=0.0.0.0/0`), the admin account can
   access from any IP address, using the password. You can filter
   subnets for the admin similarly to the public access.

## Using TiddlyWiki

Heres a few of the things I've learned using TiddlyWiki:

 * By default, there is no markdown support, but you can [easily
   install a markdown
   plugin](https://tiddlywiki.com/plugins/tiddlywiki/markdown/) (this
   must be done for each instance after install). Open two browser
   windows, one to that linked page, and one to your wiki page, and
   drag the link from the plugin page to the window containing your
   wiki, you should see a notification to install the plugin. Now you
   will find `markdown` as one the options for content type.
 * By default, the starting page only shows the `GettingsStarted`
   tiddler. Change the Default tiddlers to `[list[$:/StoryList]]` and
   you will see your most recently edited tiddlers instead.

