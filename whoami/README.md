# whoami

[whoami](https://github.com/traefik/whoami) is a tiny Go webserver
that prints os information and HTTP request to output. It is useful as
a basic deployment and connectivity test.

## Config

```
make config
```

This will ask you to enter the domain name to use, and whether or not
you want to configure a username/password via HTTP Basic Authentication.
It automatically saves your responses into the configuration file
`.env_{INSTANCE}`.

It will also ask if you want to use OpenID/OAuth2 authentication. 
Using OpenID/OAuth2 will require a login to access your app, but it will not
affect what a successfully logged-in person can do in your app. If your app has
a built-in authorization mechanism that can check for the user header that
traefik-forward-auth sends, then your app can limit what the logged-in person
can do in the app. But if your app can't check the user header, or if your app
doesn't have built-in authorization at all, then any person with an account
on your Gitea server can log into your app and have full acces

## Install

```
make install
```

## Open

```
make open
```

This will automatically open the page in your web browser, and will
prefill the HTTP Basic Authentication password if you enabled it
(and chose to store it in `passwords.json`).

## Destroy

```
make destroy
```

This completely removes the container (and would also delete all its
volumes; but `whoami` hasn't got any data to store.)
