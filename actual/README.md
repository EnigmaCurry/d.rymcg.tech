# Actual

[Actual](https://github.com/actualbudget/actual) is a local-first personal
finance tool, with functionality for envelope-style or tracking-style budgeting.
It has a synchronization element so that all your changes can move between
devices without any heavy lifting.

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

This completely removes the container (and would also delete all its
volumes; but `actual` hasn't got any data to store.)
