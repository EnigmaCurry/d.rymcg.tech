# TiddlyWiki NodeJS Server

This is the NodeJS version of [TiddlyWiki](https://tiddlywiki.com/), a
personal and shareable self-hosted wiki with powerful single-file/json
import/export features (TiddlyWiki is to wikis as SQLite is to
databases), and frictionless editability and publishing. This package
creates a hybrid static / admin interface: a static snapshot for
public guests, and dynamic live edit for authenticated admins.

Note: there are two different versions of TiddlyWiki packaged by d.rymcg.tech:

 * [tiddlywiki-nodejs](./) (this project) which is a NodeJS server,
   and the more powerful of the two options. Choose this for editing
   large TiddlyWiki sites with lots of embedded media. All media is
   stored as separate files, and in the case of images, are stored on
   external S3 ([minio](../minio)) storage.
 * [tiddlywiki-webdav](../tiddlywiki-webdav) which is a WebDAV server
   for ad-hoc hosting and editing smaller static HTML versions of
   TiddlyWiki. (All attached media is embedded in a single .html file)

## Features

This configuration of TiddlyWiki adds the following features:

 * A single domain name (eg. `wiki.example.com`) used for both the
   static snapshot and the admin page. Permalinks created from either
   view use the same URL, and can thus be used interchangeably.
 * Edit TiddlyWiki as an authenticated admin user (HTTP Basic
   Authentication, username/password).
 * Imported images are removed from the embedded html page, and moved
   to S3 storage ([minio](../minio)), given a new external canonical
   URL, and served by
   [s3-proxy](https://github.com/oxyno-zeta/s3-proxy). This helps keep
   the static html file lean and editable on mobile browsers, and
   images downloaded separately.
 * Automatic publishing to a read-only static snapshot. Guests do not
   need to be authenticated. (Turned off by default)
 * JPEG EXIF data is stripped and filenames are randomized. (The
   tiddler retains the original filename).
 * Images saved in three sizes: original, reduced 640px wide, and
   128x128 thumbnail.
 * Configurable `$:/DefaultTiddlers` so the public main page can
   display a different set of tiddlers on the main page than the admin
   backend does (eg. Display the 10 most recent Journal entries on the
   public page, and on the backend use the Story View, which sorts by
   last used).
 * `make backup` script to backup all data to your local workstation.

## Configure S3

You must create an S3 bucket to store images. You can use the
[minio](../minio) service for this, or any other S3 provider (AWS,
DigitalOcean Spaces, etc.)

### Install Minio and create a bucket

Install [minio](../minio), and then run the minio `make bucket`
target. This creates the bucket and list the credentials, for example
naming the bucket,policy,group,user, all to match the domain name for
your new tiddlywiki instance (`wiki.d.example.com`):

```
$ cd ~/git/vendor/enigmacurry/d.rymcg.tech/minio
$ make config
...
$ make install
...
$ make bucket
This will create a new bucket, policy, group, and user.
Enter a new bucket name (test): wiki.d.example.com
Enter a new policy name (wiki.d.example.com): 
Enter a new group name (wiki.d.example.com): 
Enter a new user name (wiki.d.example.com): 
...
Bucket created successfully `minio/wiki.d.example.com`.

Bucket: wiki.d.example.com
Endpoint: s3.d.example.com
Access Key: wiki.d.example.com
Secret Key: k5L7VPAIc37xS1vgx3aTYFz4s943VWPYz8L430iEUggtMbq2ahBFogDWMzge
```

## Configure

Run:

```
make config
```

Answer the questions for these variables:

 * `TIDDLYWIKI_NODEJS_TRAEFIK_HOST` the domain name for the wiki (eg.
   `wiki.d.example.com`)
 * `TIDDLYWIKI_NODEJS_HTTP_AUTH` answer the questions and this will be
   filled with your chosen username and password.
 * `TIDDLYWIKI_PUBLIC_IP_SOURCERANGE` the unauthenticated public site
   IP filter (Set to `0.0.0.0/32` by default to disable all public
   access, or `0.0.0.0/0` to allow all public access)
 * `TIDDLYWIKI_NODEJS_S3_BUCKET` the S3 Bucket name to use to store
   uploaded images. (eg `wiki.d.example.com`)
 * `TIDDLYWIKI_NODEJS_S3_ENDPOINT` the S3 Bucket endpoint domain name
   (eg. `s3.d.example.com`)
 * `TIDDLYWIKI_NODEJS_S3_ACCESS_KEY_ID` the preprovisioned S3 access
   key (eg. `wiki.d.example.com`)
 * `TIDDLYWIKI_NODEJS_S3_SECRET_KEY` the preprovisioned S3 secret key

## Install

Once configured, install TiddlyWiki:

```
make install
```

## Edit

Open the wiki in your browser:

```
make open
```

This opens your browser to the login page, with the username/password
pre-filled. To login manually, you must enter through the `/login`
path. This will prompt you to enter the username and password and then
redirect you back to `/`. To logout, you can visit `/logout`.

## Automatically publish read-only snapshot

If you set `TIDDLYWIKI_PUBLIC_IP_SOURCERANGE` appropriately for public
access (eg. `TIDDLYWIKI_PUBLIC_IP_SOURCERANGE=0.0.0.0/0`), then you
can access the site without authentication.

The page shown to guests is static, and not connected to the NodeJS
backend at all. All changes are saved in the guest's browser only and
does not affect the server.

The static snapshot is (re-)rendered automatically after every edit
made by an authenticated user.

The render includes only a subset of all the tiddlers, filtered by
tag. The default allowed tags are:

 * `Public`: all tiddlers with the `Public` tag are published, and the
   10 most recent ones are shown on the main page (By overriding
   `$:/DefaultTiddlers`).
 * `public`: all tiddlers with the `public` tag are published, but
   will not appear on the main page by default.
 * *All* of the system tiddlers (starting with `$`) are published by
   default. *Warning*: **I expect there is nothing sensitive stored in
   these system tiddlers. I hope this is not a bad assumption!!*

You can change these settings with these two environment variables:

 * `TIDDLYWIKI_PUBLIC_ALLOWED_TAGS` the list of tags allowed for
   publishing, eg `Public,public`.
 * `TIDDLYWIKI_PUBLIC_DEFAULT_TIDDLERS` the filter for the default
   tiddlers on main page, eg `[tag[Public]!sort[created]limit[10]]`.

## Backup

There is a manual backup script to backup all TiddlyWiki tiddlers and
files (eg. images).

In the tiddlywiki .env file, set `TIDDLYWIKI_NODEJS_LOCAL_BACKUP_DIR`
to a path on your workstation (by default will backup to the `backup`
directory in this project directory.

```
make backup
```

To run automatic backups, you can run `make backup` in a cron job or
systemd timer.
