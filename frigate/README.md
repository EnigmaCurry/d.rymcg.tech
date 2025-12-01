# Frigate

[Frigate](https://github.com/blakeblackshear/frigate) is a complete and local
NVR designed for Home Assistant with AI object detection. It uses OpenCV and
Tensorflow to perform realtime object detection locally for IP cameras.

## Config

```
make config
```

This will ask you to enter the domain name to use.
It automatically saves your responses into the configuration file
`.env_{INSTANCE}`.

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

This will automatically open the page in your web browser, and will prefill the
HTTP Basic Authentication password if you enabled it (and chose to store it in
`passwords.json`).

On first install, an admin user is created and its password is displayed in the
logs. Run `make show-admin-user` to display the automatically-created admin
credentials from the logs. It will look something like this:

```
INFO    : ********************************************************
INFO    : ********************************************************
INFO    : ***    Auth is enabled, but no users exist.          ***
INFO    : ***    Created a default user:                       ***
INFO    : ***    User: admin                                   ***
INFO    : ***    Password: 54d98efaad569553915b4086f7f88a49    ***
INFO    : ********************************************************
INFO    : ********************************************************
```

You should immediately log into Frigate as this admin user and change the
password.

## Destroy

```
make destroy
```

This completely removes the container and deletes all its volumes.