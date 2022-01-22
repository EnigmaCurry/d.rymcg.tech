# Nextcloud

[Nextcloud](https://nextcloud.com/) is an on-premises content collaboration
platform.

## Config

This configuration is designed to use a local PostgreSQL database and an S3
bucket as `Primary Storage`. See the Nextcloud documentation [about the
implications of using S3 for Primary
Storage](https://docs.nextcloud.com/server/latest/admin_manual/configuration_files/primary_storage.html#configuring-object-storage-as-primary-storage).

You will need an external S3 storage provider. You can use the self-hosted
[minio](../minio) config within this project, or you can use a third party S3
vendor.

You will need to prepare two S3 buckets and credentials:

 * One bucket for `Primary Storage`, all of the user created files (`OBJECTSTORE_S3_BUCKET`).
 * Another bucket for the backups. (`BACKUP_S3_BUCKET`)

Copy `.env-dist` to `.env`, and edit variables accordingly. 

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

To start Nextcloud, go into the nextcloud directory and run `docker-compose up -d`.

Immediately visit the configured domain name in your web browser to create the
administrator accout. It is recommended to **uncheck** the checkbox called
`Install recommended apps`. Its a heavy install, and you can just install the
ones you need later.

Finish the installation, and you'll end up on the dashboard screen.

## Backups

Nextcloud stores data in *three* places:

 * Accounts and config in the PostgreSQL `nextcloud_postgres` Docker volume.
 * Various config files in the `nextcloud_data` Docker volume (mounted as
   `/var/www/html` in the `nextcloud_app` container).
 * User files (uploads) in S3 bucket [Primary
   Storage](https://docs.nextcloud.com/server/latest/admin_manual/configuration_files/primary_storage.html#configuring-object-storage-as-primary-storage).

You need backups of all three.

The database holds all the metadata for the `Primary Storage`. So even if you
have the backup of the user files, it will not be readable if you don't also
have the database!

This config automatically starts two backup containers:

 * `postgres_backup` - this backs up the postgresql database (nightly) to S3.
 * `app_backup` - this backs up the server configuration (nightly) to S3.
 
There is no secondary backup of the `Primary Storage`, since it is configured
for storage on S3. You may want to back this up to a secondary bucket, but this
is left in your hands. (TODO: make separate project to replicate S3 buckets on
separate endpoints)
