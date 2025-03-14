# Speedtest Tracker

[Speedtest Tracker](https://github.com/alexjustesen/speedtest-tracker) is a
self-hosted application that monitors the performance and uptime of your
internet connection..

## Config

```
make config
```

This will ask you to enter the domain name to use. It automatically saves your
responses into the configuration file `.env_{INSTANCE}`.

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

This will automatically open the page in your web browser, and will prefill the
HTTP Basic Authentication password if you enabled it (and chose to store it in
`passwords.json`).

The intital admin login is "admin@example.com" and its password is randomly
generated and displayed during `make config`. You can also see the initial
password via `make show-password`, or find the it in the
`SPEEDTEST_TRACKER_INITIAL_ADMIN_PASSWORD` variable in the `.env_{INSTANCE}`
file. You should immediately open the app, click your avatar in the upper right
corner, and select "Profile" to change the admin login's password (also,
optionally, to change the admin login's name and email address). Once you change
the password in the app, this initial password is no longer used.

## Destroy

```
make destroy
```

This completely removes the container and all its volumes.
