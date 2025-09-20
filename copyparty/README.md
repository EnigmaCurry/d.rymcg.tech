# copyparty

[copyparty](https://github.com/9001/copyparty) is a file server
accessible from any web browser. This config can create multiple user
accounts and sub-volume permissions, including a public guest account.

At the moment, this config only supports HTTP and WebDAV access.
Copyparty itself also supports ftp, tftp, and smb/cifs, but these have
not been implemented here yet.

## Config

```
make config
```

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external
authentication on in front of your app.

Copyparty also has its own authorization system, providing
fine-grained permissioned access to authenticated clients.

### Public and guest access

This config offers configurable public (download-only) and guest (upload-only) access permissions:

 * `COPYPARTY_ENABLE_PUBLIC_ACCESS=true` - by default, public
   unauthenticated access is granted for read-only (download only)
   from the `/public` sub-volume. Set this to `false` to disable
   public access.
 * `COPYPARTY_ENABLE_GUEST_ACCESS=false` - by default, the
   unauthenticated guest upload permission is denied. To allow public
   uploads to the `/guest` sub-volume, set this variable's value to
   `true`.

### External volumes

By default, copyparty has a single docker named volume mounted at
/data. You may want to mount additional host paths into the container.
To do so, edit `COPYPARTY_VOL_EXTERNAL`, for example:

 * `COPYPARTY_VOL_EXTERNAL=ryan-music:/storage/music,bob-pics:/var/media/bob/pics`
   * This is a comma separated list of colon delimted tuples: `mount_name:host_path`
   * `mount_name` is the cointainer directory under `/mnt` where the
     volume will will be mounted (e.g. `ryan-music` is mounted at
     `/mnt/ryan-music`)
   * `host_path` is the Docker host directory that will become mounted
     into the container path. (e.g., `/storage/music`, make sure to
     give the directory liberal permissions so that the volume is
     writable by the copyparty user.)

To set the volume permissions, edit `COPYPARTY_VOL_PERMISSIONS`:

 * `COPYPARTY_VOL_PERMISSIONS=ryan-music:rw:ryan/erin,bob-pics:rw:bob,bob-pics:r:ryan`
   * This is a comma separated list of colon delimeted tuples:
     `mount_name:permission:user_list`. 
   * `mount_name` is the directory under `/mnt` where the volume will
     will be mounted (e.g. `ryan-music` is mounted at
     `/mnt/ryan-music`).
   * `permission` is the copyparty permission label (e.g., `r` for
     read-only, `w` for write-only, `rw` for read+write, `m` for
     modify, `d` for delete, `a` for admin, `rwmda` for
     read+write+modify+delete+admin)
   * `user_list` is a sub-list of users delimitted by `/` (forward
     slash) that inherit the permission.

To do anything else, guests must authenticate with a password.

To reconfigure these without re-running the entire `config` target,
you may individually run `make config-users` and/or `make config-volumes`.

## Install

```
make install
```

## Open

```
make open
```
