# Podfetch

[Podfetch](https://github.com/SamTV12345/PodFetch/tree/main) is a self-hosted
podcast manager. It is a web app that lets you download podcasts and listen
to them online. It also contains a GPodder integration so you can continue
using your current podcast app.

## Config

```
make config
```

This will ask you to enter the domain name to use, and whether or not
you want to configure a username/password via HTTP Basic
Authentication. It automatically saves your responses into the
configuration file `.env_{DOCKER_CONTEXT}`.

You customize Podfetch via environment variables, so after you make
a change in your `.env_{DOCKER_CONTEXT}`, re-run `make install`.
You can also manage users and podcasts via Podfetch's
[CLI](https://github.com/SamTV12345/PodFetch/blob/main/docs/CLI.md).

## Install

```
make install
```

## Open

```
make open
```

This will automatically open the page in your web browser, and will
prefill the password if you enabled it (and chose to store it in
`passwords.json`).

## Destroy

```
make destroy
```

This completely removes the container and any volumes.
