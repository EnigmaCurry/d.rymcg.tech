# filebrowser

[File Browser](https://filebrowser.org) is a web based file manager for multiple users.

## Create external S3 volume (optional)

You may want to follow the steps in
[RCLONE.md](https://github.com/EnigmaCurry/d.rymcg.tech/blob/master/RCLONE.md)
to setup a volume backed by remote S3 cloud storage.

If you don't use S3, you may have filebrowser connect to any other
Docker named volume.

## Config

```
make config
```

 * You need to set the username or OAuth2 email address for the admin user.
 * You may choose to use an internal (automatic) or external volume.
   If you created an S3 volume, you must choose external and then
   select it from the list of existing Docker volumes.

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external authentication on
top of your app.

If you choose OAuth2, File Browser users will be setup automatically
for authenticated users, using the default file scope (`/`).

## Install

```
make install
```

## Open

```
make open
```


