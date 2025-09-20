# copyparty

[copyparty](https://github.com/9001/copyparty) is a file server with
resumable uploads/downloads from the any web browser. This config is
for multiple users with separate permissions, including a public guest
account.

At the moment, this config only supports http and webdav access.
Copyparty itself also supports ftp, tftp, and smb/cifs, but these have
not been implemented here yet.

## Config

```
make config
```

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

By default, logged out users will have access to browse `/public` and
upload (only) to `/guest`. Each additional user you created in the
config will get their own username, password, and mount point they
will have read/write privileges of.


