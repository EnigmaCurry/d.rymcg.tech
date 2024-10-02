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

See [AUTH.md](../AUTH.md) for information on adding external authentication on
top of your app.

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
