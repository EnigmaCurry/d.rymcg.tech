# ${CREATE_TEMPLATE_PROJECT_NAME}

This is a template project based on
[whoami](https://github.com/traefik/whoami), which is a tiny Go
webserver that prints some information on every request. It is useful
as a basic deployment and connectivity test, and you can replace it in
docker-compose.yaml with any service that you want.

## Config

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
if you chose to store it locally in `passwords.json`).

## Destroy

```
make destroy
```

This completely removes the container and all of its volumes.
