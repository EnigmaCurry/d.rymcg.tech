# Rclone Volumes

[Rclone](https://rclone.org/) is a program to manage files on various
cloud storage providers, and it can mount them as directories within
your filesystem.

The [Rclone Docker Volume
Plugin](https://rclone.org/docker/#introduction) can create Docker
named volumes, using these remotes. 

The plugin is an optional feature that must be installed _on the
Docker host_.

## Automatic setup

You may use the
[s3_volume_create](https://github.com/EnigmaCurry/d.rymcg.tech/blob/master/_scripts/s3_volume_create)
script to automatically setup the host plugin and configure a volume.

```
d.rymcg.tech s3-volume
```

## Manual instructions

These are the manual instructions copied directly from the [Rclone
Docker Volume Plugin](https://rclone.org/docker/#introduction)
introduction.

```
## Install the fuse3 package on your host distro:

# e.g. debian:
d.rymcg.tech ssh apt-get -y install fuse3

# e.g. fedora:
d.rymcg.tech ssh dnf install -y fuse3
```

Create the plugin directories:

```
d.rymcg.tech ssh mkdir -p /var/lib/docker-plugins/rclone/config
d.rymcg.tech ssh mkdir -p /var/lib/docker-plugins/rclone/cache
```

Install the plugin:

```
docker plugin install rclone/docker-volume-rclone:amd64 args="-v" --alias rclone --grant-all-permissions
docker plugin enable rclone
```

```
docker plugin list
```

## Create S3 backed volume

```
S3_BUCKET=my-bucket-name
S3_PROVIDER=DigitalOcean
S3_ENDPOINT=https://nyc3.digitaloceanspaces.com
S3_REGION=nyc3
S3_ACCESS_KEY=xxxx
S3_SECRET_KEY=xxxx
S3_VOLUME=s3_${S3_BUCKET}

## Choose cache mode: 'writes' or 'full' 
## (full is less efficient but has less delay than writes)
VFS_CACHE_MODE=writes

## Batch write back delay
## (hint: set write back delay to 0s for short lived containers, 
##        otherwise set higher for efficiency.)
VFS_WRITE_BACK=5s

docker volume create ${S3_VOLUME} \
  --driver rclone \
  -o type=s3 \
  -o path=${S3_BUCKET} \
  -o s3-provider=${S3_PROVIDER} \
  -o s3-endpoint=${S3_ENDPOINT} \
  -o s3-region=${S3_REGION} \
  -o s3-access_key_id=${S3_ACCESS_KEY} \
  -o s3-secret_access_key=${S3_SECRET_KEY} \
  -o allow-other=true \
  -o vfs-cache-mode=${VFS_CACHE_MODE} \
  -o vfs-write-back=${VFS_WRITE_BACK}
```

### Test S3 volume

```
## Test
docker run --rm -it -v ${S3_VOLUME}:/data debian \
    /bin/sh -c \
    'echo Hello from Docker > \
      /data/testing.txt && \
      sync && \
      echo Syncing ... && \
      sleep 10'
```

There is a small delay as the plugin will batch writes (and the
container must remain running long enough for `VFS_WRITE_BACK` delay
to expire.)
