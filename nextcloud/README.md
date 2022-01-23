# Nextcloud

[Nextcloud](https://nextcloud.com/) is an on-premises content collaboration
platform. This config uses external S3 cloud storage for the `Primary Storage`
of user files. This config maintains a backup of the database and application
config (but not including `Primary Storage`) to a secondary S3 bucket for
backups.

*The `Primary Storage` S3 bucket (user files) is NOT backed up by this config!*

See the Nextcloud documentation [about the implications of using S3 for Primary
Storage](https://docs.nextcloud.com/server/latest/admin_manual/configuration_files/primary_storage.html#configuring-object-storage-as-primary-storage).

## Config

You will need an external S3 storage provider. You can use the self-hosted
[minio](../minio) config within this project, or you can use a third party S3
vendor.

You will need to prepare **two** S3 buckets and credentials:

 * One bucket for `Primary Storage`, all of the user created files (`OBJECTSTORE_S3_BUCKET`).
 * Another bucket for the backups. (`BACKUP_S3_BUCKET`)

Run `make config` to run the configuration wizard, or copy `.env-dist` to
`.env`, and edit variables accordingly.

 * `NEXTCLOUD_TRAEFIK_HOST` the external domain name to forward from traefik.
 * `DATABASE_PASSWORD` you must choose a secure password for the database.
 * `OBJECTSTORE_S3_BUCKET` the name of the S3 bucket for primary storage
 * `OBJECTSTORE_S3_KEY` the S3 access key ID
 * `OBJECTSTORE_S3_SECRET` the S3 secret key
 * `OBJECTSTORE_S3_HOST` the S3 endpoint domain name
 * `BACKUP_S3_BUCKET` the name of the S3 bucket for backups of database and config
 * `BACKUP_S3_KEY` the S3 access key ID
 * `BACKUP_S3_SECRET` the S3 secret key
 * `BACKUP_S3_HOST` the S3 endpoint domain name

To start Nextcloud, go into the nextcloud directory and run `make install` or
`docker-compose up -d`.

Immediately visit the configured domain name in your web browser (run `make
open`) to create the administrator accout. It is recommended to **uncheck** the
checkbox called `Install recommended apps`. It's a heavy install with this
option, and you can install apps later anyway.

Finish the installation, and you'll end up on the dashboard screen.

## Backups

Nextcloud stores data in *three* places, only two of which are backed up by this
configuration:

 * The PostgreSQL database is stored in the `nextcloud_postgres` Docker volume.
   This config creates the `postgres_backup` container to automatically backup
   the postgresql database (nightly) to S3.
 * The application files are stored in the `nextcloud_data` Docker volume
   (mounted as `/var/www/html` in the `nextcloud_app` container). This config
   creates the `app_backup` container which backs up the server configuration
   (nightly) to S3. 
 * The [Primary
   Storage](https://docs.nextcloud.com/server/latest/admin_manual/configuration_files/primary_storage.html#configuring-object-storage-as-primary-storage)
   for user created files (and uploads) in S3 bucket . ***This config does not
   create any backup for the Primary Storage**. You may want to make a backup of
   this bucket by some other means, but this is out of the scope for this
   project. (TODO: make separate project to replicate an S3 bucket to another S3
   bucket [on a different endpoint]**

The database holds all of the metadata for the `Primary Storage`. So even if you
have a backup of the user files, they will not be readable if you don't also
have a backup of the database!

**Be sure to save a copy your `.env` file someplace safe, including the S3
bucket name, endpoint, credentials, and encryption passphrase. You will need all
this information to restore from backup!**

## Make a backup now

The cron jobs will automatically run backups on schedule (`@daily` by default,
which is at midnight.) You can make a backup anytime (immediately) by running
these `Makefile` targets:

```
make backup_postgres
make backup_app
```

## Restore from backup

To completely restore Nextcloud from backup, you will need to first restore your
backup copy of the `.env` file, including your configured S3 bucket name,
endpoint, credentials, and encryption passphrase.

Bring up nextcloud as normal:

```
docker-compose up -d
```

**Do not create the admin account and do not finish the installer.***

Restore the postgresql database:

```
make restore_postgres
```

Restore the application config:

```
make restore_app
```

Now open the app in your web browser and login, everything should be restored.
