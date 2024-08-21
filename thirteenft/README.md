# 13ft

[13ft](https://github.com/wasi-master/13ft) is a simple self hosted server
that has a simple but powerful interface to block ads, paywalls, and other
nonsense.

## Note

The directory and service for "13ft" are named "thirteenft" due to
naming requirements of environment variables and docker services.

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
(`THIRTEENFT_OAUTH2_AUTHORIZED_GROUP`). Authorization groups are defined in the
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
prefill the HTTP Basic Authentication password if you enabled it
(and chose to store it in `passwords.json`).

In addition to using 13ft from its web interfact, you can also append the url
of the site you want to view at the end of the URL for 13ft and it will also
work. (e.g if your server is running at http://127.0.0.1:5000 then you can
go to http://127.0.0.1:5000/https://example.com and it will read out the
contents of https://example.com)s

## Destroy

```
make destroy
```

This completely removes the container and volumes.
