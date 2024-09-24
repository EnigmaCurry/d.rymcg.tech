# glances

[glances](https://github.com/nicolargo/glances) is an open-source system
cross-platform monitoring tool. It allows real-time monitoring of various
aspects of your system such as CPU, memory, disk, network usage etc. It also
allows monitoring of running processes, logged in users, temperatures,
voltages, fan speeds etc. It also supports container monitoring, it supports
different container management systems such as Docker, LXC. The information
is presented in an easy to read dashboard and can also be used for remote
monitoring of systems via a web interface or command line interface. 

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
You can configure OpenID/OAuth2, mTLS, or HTTP Basic Authentication.

OAuth2 uses traefik-forward-auth to delegate authentication to an external
authority (eg. a self-deployed Gitea instance). Accessing this app will
require all users to login through that external service first. Once
authenticated, they may be authorized access only if their login id matches the
member list of the predefined authorization group configured for the app
(`GLANCES_OAUTH2_AUTHORIZED_GROUP`). Authorization groups are defined in the
Traefik config (`TRAEFIK_HEADER_AUTHORIZATION_GROUPS`) and can be
[created/modified](https://github.com/EnigmaCurry/d.rymcg.tech/blob/master/traefik/README.md#oauth2-authentication)
by running `make groups` in the `traefik` directory.

mTLS (Mutual TLS) is an extension of standard TLS where both the client and
server authenticate each other using certificates. Accessing this app will
require all users to have a client mTLS certificate installed in their browser,
and this app must be configured to accept that certificate. You will be
prompted to enter one or more CN (Common Name) in a comma-separated list (a CN
is a field in a certificate that typically represents the domain name of the
server or the person/organization to which the certificate is issued). Only
certificates matching one of these CNs will be allowed access to the app, and
users with a valid mTLS certificate will be ensured secure, two-way encrypted
communication, providing enhanced security by verifying both parties'
identities.

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

## Destroy

```
make destroy
```

This completely removes the container and all its volumes.
