# backrest

[backrest](https://github.com/garethgeorge/backrest) is a web-accessible backup
solution built on top of restic. Backrest provides a WebUI which wraps the
restic CLI and makes it easy to create repos, browse snapshots, and restore
files. Additionally, Backrest can run in the background and take an opinionated
approach to scheduling snapshots and orchestrating repo health operations.

## Warning

This tool might not be the best choice to backup Docker volumes that
contain databases and/or other data that frequently changes.
Consider also
[backup-volume](https://github.com/EnigmaCurry/d.rymcg.tech/tree/master/backup-volume)
which has builtin support stopping and restarting containers before
and after scheduled backups and is therefore safer for file integrity.

## Config

```
make config
```

This will ask you to enter the domain name to use.
It automatically saves your responses into the configuration file
`.env_{INSTANCE}`.

Backrest restores files to a path in the container. In order to retrieve
restored files to your local computer, you can configure a named Docker
volume and then copy restored files from the volume's path on the host
(e.g., `/var/lib/docker/volumes/backrest_<volume-name>/_data/`) to your local
computer using `docker cp`, `rsync`, etc. Or you can configure a bind mount on
the host (e.g., `/mnt/restored-files` on the host might be an NFS share that
you have access to from your local computer, so you can configure
`/mnt/restored-files` as a bind mount in the Backrest container and Backrest
will restore files directly to the NFS share that you can access from your
local computer). When you run `make config`, you will be prompted whether to
use a named Volume or a bind mount.

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external authentication on
top of your app.

## Install

```
make install
```

## Open

```
make open
```

This will automatically open the page in your web browser, and will
prefill the HTTP Basic Authentication password if you enabled it
(and chose to store it in `passwords.json`).

When you first access Backrest, it will prompt you for required initial
configuration of an instance ID and a default user and password.

The instance ID is a unique identifier for your Backrest instance. This is
used to tag snapshots created by Backrest so that you can distinguish them
from snapshots created by other instances. This is useful if you have multiple
Backrest instances backing up to the same repo.

**Note:** the instance ID cannot be changed after initial configuration as it is
stored in your snapshots. Choose a value carefully.

If you lose your default username and password, you can reset it by deleting
the "users" key from the ~/.config/backrest/config.json file and restarting
the Backrest service.

**Note:** If you don't want to use authentication (e.g. a local only installation
or if you're using an authenticating reverse proxy) you can disabled
authentication.
    
## Destroy

```
make destroy
```

This completely removes the container and deletes all its volumes.
