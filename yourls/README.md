# YOURLS

[Yourls](https://github.com/YOURLS/YOURLS) allows you to run **Y**our **O**wn
**URL** **S**hortener which includes detailed stats, analytics, plugins, and
more.

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
(`YOURLS_OAUTH2_AUTHORIZED_GROUP`). Authorization groups are defined in the
Traefik config (`TRAEFIK_HEADER_AUTHORIZATION_GROUPS`) and can be
[created/modified](https://github.com/EnigmaCurry/d.rymcg.tech/blob/master/traefik/README.md#oauth2-authentication)
by running `d make traefik config`, selecting "Config", selecting "Middleware",
and selecting "Oauth2 sentry authorization"
([traefik-forward-auth](https://github.com/EnigmaCurry/d.rymcg.tech/tree/master/traefik-forward-auth)
must be installed).

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

### Plugins

There are many plugins available for YOURLS [here](https://github.com/YOURLS/awesome?tab=readme-ov-file#themes).
In addition to the standard plugins that YOURLS comes with, this instance
will install the following plugins automatically (you can decide whether to
activate them in the administration interface):
- Download Plugin
- Force Lowercase
- Change Password

Most plugins have a very simple installation process: just copy their
`plugin.php` (and possibly other files the plugin requires) into
`/var/www/html/user/plugins/<plugin_name>/` in the `yourls-yourls-1` container.
You can do this manually or via the "Download Plugin" plugin, which allows you
to do this from the UI.

Some plugins and themes require more manual installation or configuration
(e.g., unzipping files, moving files to the root html directory, entering an
API key).

## Open

```
make open
```

This will automatically open the page in your web browser, and will prefill
the HTTP Basic Authentication password if you enabled it (and chose to store
it in `passwords.json`).

### Admin Users

Running `make config` will ask you to create an admin user, which will have
admin access to your YOURLS instance (every other user will only be able to
create shortened URLs, if you allow them to). You can create additional admin
users by running `make add-admin-user`. You can also delete admin users by
running `make delete-admin-user`, and you can list the existing admin users
by running `make list-admin-users`.

## Destroy

```
make destroy
```

This completely removes the container and volumes.
