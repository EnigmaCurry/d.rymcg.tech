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

### Auth

If you turn on the Traefik auth middlewares, Lemmy cannot federate
properly (not even to pull from other instances). However, with auth
turned on, the app will still work as a fully private instance.

If you wish to be able to pull posts from other instances, make sure
you select `No` when asked if you wish to turn on authentication.

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
