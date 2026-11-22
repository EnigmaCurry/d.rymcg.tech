# Datetime

[Datetime](https://github.com/airyland/datetime.app) is a clean and
powerful time viewing and conversion tool designed for anyone who
needs to work with different time zones.

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

This completely removes the containers and deletes all its volumes.
