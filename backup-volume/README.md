# Backup-Volume

[backup-volume](https://github.com/EnigmaCurry/backup-volume) is a
lightweight backup solution for Docker volumes. It can backup and
upload your archives to an offsite S3 storage provider. It can
coordinate automatic shutdown of containers before backups take place
and restarting them after the backup is done.

> **ℹ️ Info:** backup-volume is designed to be simple to use,
> especially at the time when you need to restore a volume from
> backup. Each backup iteration is a full complete backup contained in
> a compressed `backup-XXXX.tar.gz` file and then copied to your
> offsite S3 storage provider. *There is no incremental backup
> feature*! All of the files are duplicated into each backup
> everytime. Automatic pruning of old backups can save some space, but
> the space and time efficiency of this style of backup is diminished
> compared to an incremental backup process like
> [restic](https://restic.net/). backup-volume is probably not the
> right solution for backup of large datasets like photos and videos,
> however it is still very useful for backing up smaller volumes. The
> feature that lets you shutdown containers before backup starts,
> creates a safe and *generic* way of backing up any container volume.
>
> A future version (in development) will need to address the
> incremental backup situation by replacing the existing backup
> procedure with restic.

## Prepare an S3 bucket offsite

You may use your own [minio](../minio) service (preferably installed
on a separate server), or any third party offsite provider (AWS,
DigitalOcean, Wasabi, etc.) You will need the following information:

 * S3 Endpoint domain. e.g., `s3.example.com`.
 * S3 bucket name. e.g., `test`
 * S3 access key id. e.g., `test`.
 * S3 secret key. e.g., `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`.

## Configure 

```
# configures the default backup instance:
make config
```

Select multiple existing volumes to backup together:

```stdout
? Select all the volumes to backup
> [x] test1_data
  [ ] forgejo_data
  [x] icecast_config
  [ ] icecast_logs
  [ ] mosquitto_mosquitto
  [ ] traefik_geoip_database
v [ ] traefik_traefik
```

Choose the schedule in [cron
format](https://github.com/EnigmaCurry/d.rymcg.tech/blob/73648904e5a954e17077368c299a23a19947ab16/backup-volume/.env-dist#L23-L59):


```stdout
BACKUP_CRON_EXPRESSION: Enter the cron expression (eg. @daily)
: @daily
```

The cron expression is interpreted in the container's timezone:
`BACKUP_TIMEZONE` if it is set, otherwise `DEFAULT_TIMEZONE` from the
root `.env_{CONTEXT}` file. `make config` does not ask for it, so to
run the schedule in a different timezone than the context default,
set it directly:

```
make reconfigure var=BACKUP_TIMEZONE=America/New_York
```

> **⚠️ Upgrade note:** before `TZ` was honored, the schedule ran in UTC.
> If your `DEFAULT_TIMEZONE` is not UTC, the next `make install` moves
> the schedule (and the `%Y-%m-%dT%H-%M-%S` timestamps in
> `BACKUP_FILENAME`) to the context timezone. Adjust
> `BACKUP_CRON_EXPRESSION` if it was picked for UTC.

Choose the retention length (number of days) to keep backup archives
before automatic pruning happens:

```stdout
BACKUP_RETENTION_DAYS: Rotate backups older than how many days? (eg. 30)
: 30
```

The archive is staged as a tar file in `/tmp` inside the container
before it is uploaded, which by default is the container's writable
layer on the Docker data root disk. If that disk does not have room for
the whole archive, enter the absolute path of a directory on the Docker
host to bind-mount at `/tmp` for staging instead. Leave it blank to use
the container's own `/tmp`.

The archive is compressed as it is written (`BACKUP_COMPRESSION`,
default `gz`). If you encrypt the backup, allow twice the archive size,
because the plain and the encrypted archive are both kept until the
backup finishes. `BACKUP_FROM_SNAPSHOT=true` also needs room for an
uncompressed copy of the sources.

```stdout
BACKUP_TMP_HOST_PATH: Enter an absolute host directory to use for staging (blank to use the container's own /tmp)
:
```

The staging directory must already exist on the Docker host, on the
mounted disk. `make install` refuses to start the container if the
directory does not exist; the short mount syntax would let Docker create
it on the root disk instead. A directory that exists but whose disk is
not mounted cannot be detected, so check it yourself on the Docker host:

```
df -h /path/to/staging
```

Create it root-owned and private, and use one directory per instance.
The archive is plaintext until it is encrypted, and is written `0644`:

```
install -d -m 0700 -o root -g root /path/to/staging
```

Every container stages inside its own `/tmp`, so instances that share one
host directory share `/tmp` as well. With `BACKUP_FROM_SNAPSHOT=true` both
use the fixed path `/tmp/backup`, and each run deletes it when it
finishes, so concurrent runs can corrupt each other. A partial archive
left behind by an interrupted run stays in the directory: the file name
has a timestamp, so a later run won't reuse it, but it uses space until
you delete it.

You can choose any of the supported storage mechanisms. For demo
purposes, choose S3:

```stdout
> Which remote storage do you want to use? s3

BACKUP_AWS_ENDPOINT: Enter the S3 endpoint (e.g., s3.example.com)
: s3.d.example.com
BACKUP_AWS_S3_BUCKET_NAME: Enter the S3 bucket name (e.g., my-bucket)
: backup-test-1
BACKUP_AWS_ACCESS_KEY_ID: Enter the S3 access key id (e.g., my-access-key)
: backup-test-1
BACKUP_AWS_SECRET_ACCESS_KEY: Enter the S3 secret access key
: OEuL3lMSdvdoFyVjEQTM4Trj/7VhHq7Q7cOFEpQPuxMHxsTVK3Hxne7st6Ty
BACKUP_AWS_S3_PATH: Choose a directory inside the bucket (blank for root)
: 
```

You may optionally preserve an additional copy of the archive in a
local volume:

```
> Do you want to keep a local backup in addition to the remote one? No
```

## Install

```
# installs the default backup instance:
make install
```

## Instances

All selections will backup to the same archive on the same schedule.
To back up different volumes on a different schedule, you should
create more than one instance and therby create separate configs:

```
# Creates a new backup instance named test:
make instance instance=test
make install instance=test
```

## Verify backup schedule

```
make logs
```

```stdout
backup-1  | 2024-10-16T02:37:00.263838944Z time=2024-10-16T02:37:00.262Z level=INFO msg="Successfully scheduled backup from environment with expression @daily"
backup-1  | 2024-10-16T02:37:00.266773318Z time=2024-10-16T02:37:00.266Z level=INFO msg="The backup will start at 12:00 AM"
````

## Restoring volumes from a backup

Each backup is self-contained in a `backup-{DATE}.tar.gz` file. Follow the [restoration procedure](https://offen.github.io/docker-volume-backup/how-tos/restore-volumes-from-backup.html) to extract it under `/var/lib/docker/volumes/`.
