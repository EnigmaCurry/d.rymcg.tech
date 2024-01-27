# gPodder

[gPodder](https://gpodder.net/) is a libre web service that allows you to manage your
podcast subscriptions and discover new content. If you use multiple devices, you can
synchronize subscriptions and your listening progress. 

```
make config
```

This will ask you to enter the domain name to use.
It automatically saves your responses into the configuration file
`.env_{INSTANCE}`.

### Authentication and Authorization

Running `make config` will ask whether or not you want to configure
authentication for your app (on top of any authentication your app provides).
You can configure OpenID/OAuth2 or HTTP Basic Authentication.

OAuth2 uses traefik-forward-auth to delegate authentication to an external
authority (eg. a self-deployed Gitea instance). Accessing this app will
require all users to login through that external service first. Once
authenticated, they may be authorized access only if their login id matches the
member list of the predefined authorization group configured for the app
(`WHOAMI_OAUTH2_AUTHORIZED_GROUP`). Authorization groups are defined in the
Traefik config (`TRAEFIK_HEADER_AUTHORIZATION_GROUPS`) and can be
[created/modified](https://github.com/EnigmaCurry/d.rymcg.tech/blob/master/traefik/README.md#oauth2-authentication)
by running `make groups` in the `traefik` directory.

For HTTP Basic Authentication, you will be prompted to enter username/password
logins which are stored in that app's `.env_{INSTANCE}` file.


### `make` alternative
As an alternative to running `make config`, copy `.env-dist` to `.env_${DOCKER_CONTEXT}_{INSTANCE}`, and edit these
variables:

 * `GPODDER_TRAEFIK_HOST` the external domain name to forward from traefik for
 the main site.
 * `GPODDER_UID` the UID the docker container should run as
 * `GPODDER_GID` the GID the docker container should run as
 * `GPODDER_PW` password for the gPodder GUI (optional)
 * `GPODDER_TZ` the timezone the container should run as
 * `GPODDER_PORT` the port gPodder should use

```
make config
```

```
make open
```
