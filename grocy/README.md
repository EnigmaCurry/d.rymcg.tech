# Grocy

[Grocy](https://grocy.info/)
is a web-based self-hosted groceries & household management solution for
your home.

## Configure

Run:

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

Run:

```
make install
```

## Open in your web browser

Run:

```
make open
```

Login using your HTTP Basic Authentication and/or Oauth2 authentication if
you configured them, then log into Grocy with these default credentials:

 * Username: `admin`
 * Password: `admin`

(You should immediately change these upon login)
