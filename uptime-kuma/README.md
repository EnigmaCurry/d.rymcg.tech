# Uptime Kuma

[Uptime Kuma](https://github.com/louislam/uptime-kuma) is a
self-hosted monitoring tool that can alert you if a system or service
becomes inaccessible. It has configurable status pages and a
notification system.

## Config

```
make config
```

This will ask you to enter the domain name to use. It automatically
saves your responses into the configuration file
`.env_{DOCKER_CONTEXT}_{INSTANCE}`.

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external
authentication on top of your app.

If you are adding sentry auth in front of Uptime Kuma, notice that
there is a setting in the Uptime Kuma to disable auth, so you could
rely entirely on the sentry auth if you wanted to.

## Install

```
make install
```

## Open

```
make open
```

Finish the installation / onboarding in the browser.

## Destroy

```
make destroy
```
