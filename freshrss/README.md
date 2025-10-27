[FreshRSS](https://freshrss.org/) is a self-host RSS aggregator.

Compare with [ttrss](../_attic/ttrss)

## Config

```
make config
```

This will ask you to enter the domain name to use. It automatically
saves your responses into the configuration file
`.env_{DOCKER_CONTEXT}_{INSTANCE}`.

The default timezone of the server will be Europe/Paris. To change it,
edit the value for `TIME_ZONE` in the configuration file
`.env_{DOCKER_CONTEXT}_{INSTANCE}`

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external
authentication on top of your app.

## Install

```
make install
```

## Open

```
make open
```

This will automatically open the page in your web browser, and will
prefill the HTTP Basic Authentication password if you enabled it (and
chose to store it in `passwords.json`).

Immediately open the app and finish the installation with the wizard.
Choose the SQLite database type when asked.

## Destroy

```
make destroy
```

This completely removes the container and volumes.
