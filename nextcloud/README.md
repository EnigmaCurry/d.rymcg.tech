# Nextcloud

[Nextcloud](https://nextcloud.com/) is a self-hosted content collaboration
platform. This config includes automated and encrypted backups of the database
and all data to S3 cloud storage (or compatible S3 API endpoint.)

## Config

You need to create the S3 bucket that will be used for backups. You can use the
included [minio](../minio) service for testing purposes, or choose your own S3
vendor for production.

Run `make config` to run the configuration wizard, or copy `.env-dist` to
`.env`, and edit variables accordingly.

 * `NEXTCLOUD_TRAEFIK_HOST` the external domain name to forward from traefik.
 * `DATABASE_PASSWORD` you must choose a secure password for the database.
 * `BACKUP_S3_BUCKET` the name of the S3 bucket for backups of database and data
 * `BACKUP_S3_KEY` the S3 access key ID
 * `BACKUP_S3_SECRET` the S3 secret key
 * `BACKUP_S3_HOST` the S3 endpoint domain name

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

**Be sure to save a copy your `.env` file someplace safe, including the S3
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
backup copy of the `.env` file, including your configured S3 bucket name,
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

By default, all data is stored in the `nextcloud_data` docker volume, mounted as
`/var/www/html/data`. Object Storage allows for the Primary Storage (user files)
to be stored externally in an S3 bucket. This is optional, and is disabled in
the default `.env-dist`.

See the Nextcloud documentation [about the implications of using S3 for Primary
Storage](https://docs.nextcloud.com/server/latest/admin_manual/configuration_files/primary_storage.html#configuring-object-storage-as-primary-storage).

**If you use Object Storage, the `Primary Storage` S3 bucket (user files) is NOT
included in the backup scripts!**

**Nextcloud does not encrypt files in object storage! (the backups are though)**

To enable Object Storage do the following:

 * Create a new S3 bucket (not the same one you used for backups)
 * Uncomment the `OBJECTSTORE_S3_*` variables in your `.env` and set the values
   for your S3 bucket, endpoint, and credentials.
