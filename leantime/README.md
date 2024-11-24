# leantime

[leantime](https://github.com/Leantime/leantime/) is an open source project
management system for non-project managers. It combines strategy, planning,
and execution, and is built with with ADHD, dyslexia, and autism in mind. It's
an alternative to ClickUp, Monday, or Asana, and is as simple as Trello but
as feature-rich as Jira.

## Config

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

```
make install
```

Immediately run Leantime's installation script and create the admin user:
```
make init
```
(or you can manually visit `https://${LEANTIME_TRAEFIK_HOST}/install`)

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

This completely removes the container and delete all its volumes.
