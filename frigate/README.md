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

By default, Frigate's webserver only accepts TLS connections. But as we're
installing it behind Traefik, which terminates TLS and forwards http traffic,
we need to disable TLS on Frigate's webserver before we can use it. If you
don't, you'll see a "400 Bad Request: The plain HTTP request was sent to HTTPS
port" error. Run the following command to disable TLS on Frigate's webserver
and restart the container:

```
make disable-tls
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