# Grocy

[Grocy](https://grocy.info/)
is a web-based self-hosted groceries & household management solution for
your home.

## Configure

Run:

```
make config
```

This will ask you to enter the domain name to use.
It automatically saves your responses into the configuration file
`.env_{INSTANCE}`.

### Authentication and Authorization

Running `make config` will ask whether or not you want to configure
authentication for your app (on top of any authentication your app provides).
You can choose to enter username/password logins via HTTP Basic Authentication,
or authorization groups containing email addresses via OpenID/OAuth2 (to
configure your authorization groups, run `make config` in the `traefik` directory).

*SECURITY NOTE:* Using OpenID/OAuth2 will require a login to access
your app. You can configure basic authorization by [creating groups](https://github.com/EnigmaCurry/d.rymcg.tech/blob/header-authorization/traefik/README.md#oauth2-authentication)
of email addresses that are allowed to log into
your app. Email addresses must match those of accounts on your Gitea instance.
For example, if you have accounts on your Gitea instance for
alice@example.com and bob@demo.com, and you only want Alice to be able to
access this app, only enter `alice@example.com`.

Using OpenID/OAuth2 is on top of any
authentication/authorization service your app provides. OpenID/Oauth2 will
require a login to access your app and permit only specific logins, but it
will not affect what a successfully logged-in person can do in your app. If
your app has a built-in authorization mechanism that can check for the user
header that traefik-forward-auth sends, then your app can limit what the
logged-in person can do in the app. But if your app can't check the user
header, or if your app doesn't have built-in authorization at all, then any
person with an account on your Gitea server that you permit to log into your
app will have full access.

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
