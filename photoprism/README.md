# photoprism

[PhotoPrism®](https://hub.docker.com/r/photoprism/photoprism) is an
AI-Powered Photos App for the Decentralized Web.

## Config

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

You'll also be prompted to enter a few configurations for PhotoPrism,
but there are other Photoprism options you can configure by manually
editing your `.env_{DOCKER_CONTEXT}` file. If you add more media volumes,
be sure to add them to `docker-compose.yaml` as well; and if you add an
import volume, be sure to uncomment the corresponding line in the 
`photoprism` service in `docker-compose.yaml` as well.

## Install

```
make install
```

## Open

```
make open
```

This will automatically open the page in your web browser, and will
prefill the HTTP Basic Authentication password if you enabled it (and chose
to store it in `passwords.json`).

Photoprism also has it's own authentication, and the initial password for
the "admin" account (whatever you entered for `PHOTOPRISM_ADMIN_USER`)
is "password". You should change this from within Photoprism.

## Destroy

```
make destroy
```

This completely removes the container (and would also delete all its
volumes).
