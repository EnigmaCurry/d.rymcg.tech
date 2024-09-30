# Audiobookshelf

[Audiobookshelf](https://github.com/advplyr/audiobookshelf)
is a self-hosted audiobook and podcast server.

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
