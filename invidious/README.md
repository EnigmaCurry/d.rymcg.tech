# Invidious

[Invidious](https://github.com/iv-org/invidious) is an alternative front-end to
YouTube.

This install assumes you want a private instance, protected by
username/password. If not, comment out the `Authentication` section in the
`docker-compose.yaml`.

```
make config
```

This will ask you to enter the domain name to use.
It automatically saves your responses into the configuration file
`.env_{INSTANCE}`.

If you are using ARM64, you must select the appropriate image:

```
make reconfigure var=INVIDIOUS_IMAGE=quay.io/invidious/invidious:latest-arm64
```

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external authentication on
top of your app.

```
make install
```

```
## Wait for all services to become HEALTH=healthy; Press Ctrl-C to quit watch
watch make status
```

```
make open
```

## Notes on invidious

The default setting is for clients to stream videos directly from Google. If
this is not desired, make sure you set the setting in the client interface
called `Proxy videos`. Also see [invidious docs on
this](https://github.com/iv-org/documentation/blob/master/Always-use-%22local%22-to-proxy-video-through-the-server-without-creating-an-account.md).

You should create an invidious account and log into the app, in addition to the
HTTP basic auth password. If you don't create an account, and you don't login,
your settings (eg. `Proxy Videos`) are not saved!

