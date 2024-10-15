# Backup-Volume

[backup-volume](https://github.com/EnigmaCurry/backup-volume) is a
lightweight backup solution for Docker volumes. It can backup and
upload your archives to an offsite S3 storage provider. It can
coordinate automatic shutdown of containers before backups take place
and restarting them after the backup is done.

> **ℹ️ Info:** backup-volume is designed to be simple to use,
> especially at the time when you need to restore a volume from
> backup. Each backup is a full backup contained in a compressed
> `backup-XXXX.tar.gz` file and then copied to your offsite S3 storage
> provider. There is no incremental backup feature, all of the files
> are duplicated into each backup everytime. Automatic pruning of old
> backups can save some space, but the space and time efficiency of
> this style backup is diminished compared to an incremental backup
> like [restic](https://restic.net/). backup-volume is probably not
> the right solution for backup of large datasets like photos and
> videos, however it is still very useful for backing up smaller
> volumes. The feature that lets you shutdown containers before backup
> starts, creates a safe and *generic* way of backing up any container
> volume.

## Prepare an S3 bucket offsite

You may use your own [minio](../minio) service, or any third party
provider (AWS, DigitalOcean, Wasabi, etc.) You need the following
information:

 * S3 Endpoint domain. e.g., s3.example.com



## Configure 

```
make config
```
