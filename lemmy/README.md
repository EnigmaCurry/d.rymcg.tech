# Lemmy

[Lemmy](https://github.com/LemmyNet/lemmy) is a link aggregator and forum
for the fediverse.

## Config

```
make config
```

This will ask you to enter the domain name to use.
It automatically saves your responses into the configuration file
`.env_{INSTANCE}`.

### Authentication and Authorization

Lemmy will not function properly with authentication on top of Lemmy's own
authentication, so it's not offered when you run `make config`.

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

## Destroy

```
make destroy
```

This completely removes the container and all its
volumes.
