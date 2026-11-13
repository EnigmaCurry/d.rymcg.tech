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
fine-grained permissioned access to authenticated clients. Login is
performed by password ONLY (no username needs to be entered. Also,
passwords must be unique).

`make config` generates a random password for the admin user and
saves it as `COPYPARTY_ADMIN_PASSWORD` in your
`.env_{DOCKER_CONTEXT}_{INSTANCE}` file (view or change it with `make
config-edit`; do not use commas, colons, or spaces).

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

### User home folders

 * `COPYPARTY_ENABLE_USER_HOMES=false` - set this to `true` to give
   every account (the admin and each user in `COPYPARTY_USERS`) a
   private home folder at `/home/{username}`. The data is stored
   in the `copyparty_data` named volume at `/data/home/{username}`, so
   you don't need to make an external volume for each user. Each user
   has full `rwmda` permission on their own home, and the admin can
   access all of them. This uses copyparty's `${u}` volume expansion,
   so new users automatically get a home the next time the service
   is (re)started.

### External volumes

By default, copyparty has a single docker named volume mounted at
/data. You may want to mount additional host paths into the container.
To do so, edit `COPYPARTY_VOL_EXTERNAL`, for example:

 * `COPYPARTY_VOL_EXTERNAL=ryan-music:/storage/music,bob-pics:/var/media/bob/pics`
   * This is a comma separated list of colon delimited tuples: `mount_name:host_path`
   * `mount_name` is the container directory under `/mnt` where the
     volume will be mounted (e.g. `ryan-music` is mounted at
     `/mnt/ryan-music`), and the copyparty volume URL (`/ryan-music`).
   * `host_path` is the absolute path (starting with `/`) of a
     directory on the Docker host, which is bind-mounted into the
     container (e.g., `/storage/music`). Make sure the directory is
     writable by the copyparty user (`COPYPARTY_UID`). Docker named
     volumes are not supported here, and the path cannot contain
     commas, colons, or spaces.

### Path permissions

To give users access to folders, edit `COPYPARTY_PERMISSIONS`:

 * `COPYPARTY_PERMISSIONS=/ryan-music:rw:ryan/erin,/bob-pics:rw:bob,/bob-pics:r:ryan,/team-docs:rw:ryan/bob`
   * This is a comma separated list of colon delimited tuples:
     `path:permission:user_list`.
   * `path` is the copyparty URL path (e.g. `/team-docs`):
     * If its first part is an external volume name (e.g.
       `/ryan-music`, or `/ryan-music/live` for a sub-folder), it is
       stored on that external volume.
     * Any other path is stored in the `copyparty_data` named volume
       (e.g. `/team-docs` is stored at `/data/team-docs`), and its
       folder is created for you.
     * `/admin`, `/public`, `/guests`, `/home` and `/share` are
       reserved for copyparty's built-in volumes.
   * `permission` is the copyparty permission label (e.g., `r` for
     read-only, `w` for write-only, `rw` for read+write, `m` for
     modify, `d` for delete, `a` for admin, `rwmda` for
     read+write+modify+delete+admin)
   * `user_list` is a sub-list of users delimited by `/` (forward
     slash) that get the permission.
   * The same path may be listed several times, with different
     permissions for different users.
   * Each path becomes its own copyparty volume, and copyparty volumes
     do **not** inherit permissions from a parent path. For example,
     with `/team-docs:rw:ryan/bob,/team-docs/private:rw:ryan`, bob
     can't access `/team-docs/private`. Give each path its full list
     of users.
   * The admin always gets full (`rwmda`) permission on every path.

`COPYPARTY_PERMISSIONS` replaces the old `COPYPARTY_VOL_PERMISSIONS`
(`mount_name:permission:user_list`). If your `.env` file still has
`COPYPARTY_VOL_PERMISSIONS`, it is converted automatically when
copyparty starts, and `make config-volumes` rewrites it as
`COPYPARTY_PERMISSIONS`.

To do anything else, guests must authenticate with a password.

To reconfigure these without re-running the entire `config` target,
you may individually run `make config-users` and/or `make config-volumes`.

## Install

```
make install
```

## Open

Copyparty has a web interface you may want to open in your web browser:

```
make open
```

## Mount copyparty volumes on your local computer

In addition to its web interface, copyparty exposes its storage via the open WebDAV protocol. Many desktop file explorer programs have native WebDAV support, meaning you can mount your remote copyparty folders on your local computer (e.g., Thunar + GVFS). Unfortunately, many of these same programs do not support client TLS certificates. A more robust method of mounting WebDAV folders is via [Rclone](https://rclone.org/), which will work with any system or file explorer, and has support for mTLS. Follow the blog post [WebDAV with Rclone and mTLS](https://blog.rymcg.tech/blog/linux/rclone_webdav/) to set this up on your computer.
