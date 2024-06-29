# Nextcloud

[Nextcloud](https://nextcloud.com/) is a self-hosted content collaboration
platform. This config includes automated and encrypted backups of the database
and all data to S3 cloud storage (or compatible S3 API endpoint.)

## Config

First, you need to create the S3 bucket that will be used for backups, and you
can optionally create an S3 bucket that will be used for Primary Storage (see
the [Enable Object Storage](#enable-object-storage) section). You can use the
included [minio](../minio) service for testing purposes, or choose your own S3
vendor for production.

Run `make config` to run the configuration wizard, or copy `.env-dist` to
`.env_${DOCKER_CONTEXT}_default`, and edit variables accordingly.

 * `NEXTCLOUD_TRAEFIK_HOST` the external domain name to forward from traefik.
 * `NEXTCLOUD_DATABASE_PASSWORD` you must choose a secure password for the database.
 
By default, Primary Storage is stored in the `nextcloud_data` docker volume.
Optionally, you can store this data externally in an S3 Bucket instead.
 * `NEXTCLOUD_PRIMARY_STORAGE` either "Docker Volume" or "S3 Bucket"
 * `NEXTCLOUD_OBJECTSTORE_S3_HOST` the S3 endpoint domain name for Primary Storage (this is ignored if NEXTCLOUD_PRIMARY_STORAGE=Docker Volume)
 * `NEXTCLOUD_OBJECTSTORE_S3_BUCKET` the name of the S3 bucket for Primare Storage (this is ignored if NEXTCLOUD_PRIMARY_STORAGE=Docker Volume)
 * `NEXTCLOUD_OBJECTSTORE_S3_KEY` the S3 access key ID for Primary Storage (this is ignored if NEXTCLOUD_PRIMARY_STORAGE=Docker Volume)
 * `NEXTCLOUD_OBJECTSTORE_S3_SECRET`= the S3 secret key for Primary Storage (this is ignored if NEXTCLOUD_PRIMARY_STORAGE=Docker Volume)
 * `NEXTCLOUD_BACKUP_S3_HOST` the S3 endpoint domain name for backups of database and data
 * `NEXTCLOUD_BACKUP_S3_BUCKET` the name of the S3 bucket for backups of database and data
 * `NEXTCLOUD_BACKUP_S3_KEY` the S3 access key ID for backups of database and data
 * `NEXTCLOUD_BACKUP_S3_SECRET` the S3 secret key for backups of database and data

### Authentication and Authorization

Running `make config` will ask whether or not you want to configure
authentication for your app (on top of any authentication your app provides).
You can configure OpenID/OAuth2 or HTTP Basic Authentication.

OAuth2 uses traefik-forward-auth to delegate authentication to an external
authority (eg. a self-deployed Gitea instance). Accessing this app will
require all users to login through that external service first. Once
authenticated, they may be authorized access only if their login id matches the
member list of the predefined authorization group configured for the app
(`WHOAMI_OAUTH2_AUTHORIZED_GROUP`). Authorization groups are defined in the
Traefik config (`TRAEFIK_HEADER_AUTHORIZATION_GROUPS`) and can be
[created/modified](https://github.com/EnigmaCurry/d.rymcg.tech/blob/master/traefik/README.md#oauth2-authentication)
by running `make groups` in the `traefik` directory.

For HTTP Basic Authentication, you will be prompted to enter username/password
logins which are stored in that app's `.env_{INSTANCE}` file.

## Install

To start Nextcloud, go into the nextcloud directory and run `make install`.

Immediately visit the configured domain name in your web browser (run `make
open`) and create the administrator accout. It is recommended to **uncheck** the
checkbox called `Install recommended apps`. It's a heavy install with this
option, and you can install additional apps later anyway.

Finish the installation, and you'll end up on the dashboard screen.

## Backups

Nextcloud stores data in *two* places (possibly *three* if you turn on Object
Storage):

 1. The PostgreSQL database is stored in the `nextcloud_postgres` Docker volume.
   This config creates the `postgres_backup` container to automatically backup
   the PostgreSQL database (nightly) to S3.
 2. The application data is stored in the `nextcloud_data` Docker volume
   (mounted as `/var/www/html` in the `nextcloud_app` container). This config
   creates the `data_backup` container which creates a backup (nightly) to S3.
 3. The `Primary Storage` for user created files (and uploads) is in
   `/var/www/html/data`, which by default is already included in the
   `data_backup` of `/var/www/html`. However, if you choose to enable Object
   Storage, user files will be stored externally in S3 and will not be backed up
   by this configuration anymore.

**Be sure to save a copy your `.env_${DOCKER_CONTEXT}_default` file someplace safe, including the S3
bucket name, endpoint, credentials, and encryption passphrase. You will need all
this information if you need to restore from backup!**

## Make a backup now

The cron jobs will automatically run backups on schedule (`@daily` by default,
which is at midnight.) You can make a backup anytime (immediately) by running
these `Makefile` targets:

```
make backup_db
make backup_data
```

Look inside the S3 bucket and you'll find a directory tree that looks like this:

 * nextcloud.example.com/
   * data/
     * (contents is an encrypted restic repository of /var/www/html backup)
   * postgres/
     * (contents is encrypted postgresql dump files)

(With this structure you can re-use this bucket for backups of other hostnames
too.)

## Restore from backup

To completely restore Nextcloud from backup, you will need to first restore your
backup copy of the `.env_${DOCKER_CONTEXT}_default` file, including your configured S3 bucket name,
endpoint, credentials, and encryption passphrase.

Bring up nextcloud as normal:

```
make install
```

**Do not create the admin account and do not finish with the installer.**

Restore the PostgreSQL database:

```
make restore_db
```

Restore the application config and data, into maintenance mode:

```
make restore_data
```

When both are restored successfully, disable maintenance mode :

```
make disable_maintenance
```

Now open the app in your web browser (`make open`) and login, everything should
be restored.


## Enable Object Storage

By default, all data is stored in the `nextcloud_data` Docker volume, mounted as
`/var/www/html/data`. Object Storage allows for the Primary Storage (user files)
to be stored externally in an S3 bucket. This is optional, and Primary Storage
is set to be saved in a Docker volume in the default `.env-dist`.

See the Nextcloud documentation [about the implications of using S3 for Primary
Storage](https://docs.nextcloud.com/server/latest/admin_manual/configuration_files/primary_storage.html#configuring-object-storage-as-primary-storage).

**If you use Object Storage, the `Primary Storage` S3 bucket (user files) is NOT
included in the backup scripts!**

**Nextcloud does not encrypt files in object storage! (the backups are though)**

To enable Object Storage do the following:

 * Create a new S3 bucket (not the same one you used for backups)
 * Run `make config` and select "S3 Bucket" for "Primary Storage" (or manually
   change the `NEXTCLOUD_PRIMARY_STORAGE` variable to `S3 Bucket` in your
   `.env_${DOCKER_CONTEXT}_default` and set the values for your Object
   Storage S3 bucket, endpoint, and credentials).
