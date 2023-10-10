# Invidious

[Invidious](https://github.com/iv-org/invidious) is an alternative front-end to
YouTube.

This install assumes you want a private instance, protected by
username/password. If not, comment out the `Authentication` section in the
`docker-compose.yaml`.

```
make config
```

This will ask you to enter the domain name to use, and whether or not
you want to configure a username/password via HTTP Basic Authentication.
It automatically saves your responses into the configuration file
`.env_{INSTANCE}`.

It will also ask if you want to use OpenID/OAuth2 authentication. Using
OpenID/OAuth2 will require a login to access your app, but it will not affect
what a successfully logged-in person can do in your app. If your app has
built-in authentication and can check the user header that
traefik-forward-auth sends, then your app can limit what the logged-in person
can do in the app. But if your app can't check the user header, or if your app
doesn't have built-in authentication at all, then any person with an account
on your Gitea server can log into your app and have full access.

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

