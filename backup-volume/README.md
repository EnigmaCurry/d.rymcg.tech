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
> offsite S3 storage provider. There is no incremental backup feature,
> all of the files are duplicated into each backup everytime.
> Automatic pruning of old backups can save some space, but the space
> and time efficiency of this style backup is diminished compared to
> an incremental backup process like [restic](https://restic.net/).
> backup-volume is probably not the right solution for backup of large
> datasets like photos and videos, however it is still very useful for
> backing up smaller volumes. The feature that lets you shutdown
> containers before backup starts, creates a safe and *generic* way of
> backing up any container volume.

## Prepare an S3 bucket offsite

You may use your own [minio](../minio) service, or any third party
provider (AWS, DigitalOcean, Wasabi, etc.) You need the following
information:

 * S3 Endpoint domain. e.g., `s3.example.com`.
 * S3 bucket name. e.g., `test`
 * S3 access key id. e.g., `test`.
 * S3 secret key. e.g., `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`.

## Configure 

```
# configures the default backup instance:
make config
```

Select some existing volumes to backup together.

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


```stdout
BACKUP_CRON_EXPRESSION: Enter the cron expression (eg. @daily)
: @daily
```

Choose the schedule in [cron
format](https://github.com/EnigmaCurry/d.rymcg.tech/blob/73648904e5a954e17077368c299a23a19947ab16/backup-volume/.env-dist#L23-L59).

```stdout
BACKUP_RETENTION_DAYS: Rotate backups older than how many days? (eg. 30)
: 30
```

Choose the retention length (number of days) to keep backup archives
before automatic pruning happens.

```stdout
> Which remote storage do you want to use? s3
```

You can choose any of the supported storage mechanisms, for demo
purposes, choose S3.

```stdout
BACKUP_AWS_ENDPOINT: Enter the S3 endpoint (e.g., s3.example.com)
: s3.pi5.forwarding.network
BACKUP_AWS_S3_BUCKET_NAME: Enter the S3 bucket name (e.g., my-bucket)
: backup-test-1
BACKUP_AWS_ACCESS_KEY_ID: Enter the S3 access key id (e.g., my-access-key)
: backup-test-1
BACKUP_AWS_SECRET_ACCESS_KEY: Enter the S3 secret access key
: OEuL3lMSdvdoFyVjEQTM4Trj/7VhHq7Q7cOFEpQPuxMHxsTVK3Hxne7st6Ty
BACKUP_AWS_S3_PATH: Choose a directory inside the bucket (blank for root)
: 
```

Enter the connection information for the S3 bucket. (You can create a
bucket using
[minio](https://github.com/EnigmaCurry/d.rymcg.tech/tree/master/minio#readme),
preferably installed on a separate server).


```
> Do you want to keep a local backup in addition to the remote one? No
```

You may optionally preserve an additional copy of the archive in a
local volume.

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
