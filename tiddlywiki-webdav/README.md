# TiddlyWiki

[TiddlyWiki](https://tiddlywiki.com/) is a non-linear notebook for
capturing, organising, and sharing complex information. TiddlyWiki
stores itself, and the entire wiki database, inside of a single
`.html` file. TiddlyWiki can save itself to many different storage
backends, but by default it uses WebDAV and pushes changes back to the
same server and path that it is served from.

Note: there are two different versions of TiddlyWiki packaged by d.rymcg.tech:

 * [tiddlywiki-webdav](./) (this project) which is a WebDAV server for
   hosting and editing small static HTML versions of TiddlyWiki. (all
   attached media is embedded in the .html)
 * [tiddlywiki-nodejs](../tiddlywiki-nodejs) which is a NodeJS server
   for editing larger TiddlyWiki sites with lots of embedded media.
   All media is stored as separate files, and in the case of images,
   are stored on external S3 ([minio](../minio)) storage.

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

## Automatic backup to a git repository

Although TiddlyWiki has a builtin GitHub, GitLab, and Gitea "saver",
it only works with a standalone file install (ie, when *not* served by
WebDAV, but just a file on your disk). Having TiddlyWiki save to two
destinations might get confusing, so TiddlyWiki turns the git saver
off when WebDAV saving is enabled.

To use both WebDAV, *and* to have backups to a git repository, you
must enable the `git-autocommit` sidecar service on the server. The
`git-autocommit` service will monitor the TiddlyWiki's
`/www/index.html` and whenever changes occur, it will commit and push
the changeset to your remote git repository. That way you benefit from
a centralized location to edit (WebDAV server), and an automatic
external backup.

The `git-autocommit` service is optional, and disabled by default (see
`DOCKER_COMPOSE_PROFILES`).

### Create a private git repository to hold the backups

Create a private repository on your git forge (GitHub, GitLab, Gitea,
etc.) and add an SSH deploy key.

For example, on GitHub:

 * [Create a new repository](https://github.com/new)
 * Choose a repository name like `tiddlywiki-backups`
 * Choose visibility: `Private`.

One repository can handle the backups for several instances of
TiddlyWiki. Each instance will have its own deploy key, and a unique
git branch named the same as the instance's configured
`${TIDDLYWIKI_TRAEFIK_HOST}`. (Having a unique git branch for each
instance helps to avoid unnecessary push conflicts.)

### Configure the GIT_BACKUP_REPO variable

From the private repository page, find the SSH git URL, eg: `git@github.com:{USERNAME}/{REPOSITORY}.git`

Add the git remote URL to your environment file:

```
make reconfigure var=TIDDLYWIKI_GIT_BACKUP_REPO=git@github.com:Your_Username/tiddlywiki-private.git
```

### Generate the SSH keys for the `git-autocommit` service:

```
make ssh-keygen
```

This will create new SSH keys and store them in a volume for the
service. The SSH public key will be printed to the screen, which you
will need to copy and paste into the deploy key setting of the remote
git repository.

### Add the deploy key to the git forge

For example on GitHub:

 * Find the repository `Settings` page.
 * Find `Deploy keys` and click `Add deploy key`.
 * Enter a descriptive Title, eg: `wiki.example.com git-autocommit bot`
 * Paste the SSH key output from the previous step.
 * Click to checkmark `Allow write acces`.
 * Click `Add key`.

### Enable the git-autocommit service and redeploy

Update the `DOCKER_COMPOSE_PROFILES` variable in your config to turn
on the `git-autocommit` service (which is disabled by default in
[.env-dist](.env-dist)):

```
make reconfigure var=DOCKER_COMPOSE_PROFILES=default,git-autocommit
make install
```

### Verify the backup is working

Check the logs:

```
make logs SERVICE=git-autocommit
```

Also verify that there is a new commit pushed to your remote
repository, for each change you make in TiddlyWiki.
