# Audiobookshelf

[Audiobookshelf](https://github.com/advplyr/audiobookshelf)
is a self-hosted audiobook and podcast server.

## Configure

Run:

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

## Install

Run:

```
make install
```

## Open in your web browser

Run:

```
make open
```
