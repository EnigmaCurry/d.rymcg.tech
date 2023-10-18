# Piwigo

[Piwigo](https://piwigo.org/) is an online photo gallery and manager.

Run `make config` to automatically configure your
`.env_${DOCKER_CONTEXT}_default` file. 

This will ask you to enter the domain name to use.
It automatically saves your responses into the configuration file
`.env_{INSTANCE}`.

Alternatively to running `make config`, you can manually copy
`.env-dist` to `.env_${DOCKER_CONTEXT}_default` and edit the variables accordingly:

 * `PIWIGO_TRAEFIK_HOST` the external domain name to forward from traefik.
 * `MARIADB_ROOT_PASSWORD` the root mysql password
 * `MARIADB_DATABASE` the mysql database name
 * `MARIADB_USER` the mysql database username
 * `MARIADB_PASSWORD` the mysql user password
 * `TIMEZONE` the timezone, in the format of [TZ database name](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)
 * `PIWIGO_OAUTH2` set to `yes` to configure Oauth2 authentication (in addition to Piwigo's own internal authentication)
 * `PIWIGO_AUTHORIZED_IDENTITIES` enter a comma-separated list of email addresses authorized to log into this app (must match Gitea accounts)
 * `PIWIGO_HTTP_AUTH` it's easiest to configure this variable via `make config`, but you can manually enter 1 or more credentials in the format `<username>:<password hashed by htpasswd>[,<username2>:<htpasswd-hashed password 2>...]`

### Authentication and Authorization

Running `make config` will ask whether or not you want to configure
authentication for your app (on top of any authentication your app provides).
You can choose to enter username/password logins via HTTP Basic Authentication,
or authorization groups containing email addresses via OpenID/OAuth2 (to
configure your authorization groups, run `make config` in the `traefik` directory).

*SECURITY NOTE:* Using OpenID/OAuth2 will require a login to access
your app. You can configure basic authorization by [creating groups](https://github.com/EnigmaCurry/d.rymcg.tech/blob/header-authorization/traefik/README.md#oauth2-authentication)
of email addresses that are allowed to log into
your app. Email addresses must match those of accounts on your Gitea instance.
For example, if you have accounts on your Gitea instance for
alice@example.com and bob@demo.com, and you only want Alice to be able to
access this app, only enter `alice@example.com`.

Using OpenID/OAuth2 is on top of any
authentication/authorization service your app provides. OpenID/Oauth2 will
require a login to access your app and permit only specific logins, but it
will not affect what a successfully logged-in person can do in your app. If
your app has a built-in authorization mechanism that can check for the user
header that traefik-forward-auth sends, then your app can limit what the
logged-in person can do in the app. But if your app can't check the user
header, or if your app doesn't have built-in authorization at all, then any
person with an account on your Gitea server that you permit to log into your
app will have full access.


Once the `.env_${DOCKER_CONTEXT}_default` file is configured install piwigo:

```
make install
```

Open the app:

```
make open
```

When you first start up piwigo, you must immediately configure it, as
it is left open to the world in an insecure initial state (though there is
some protection is you configured HTTP Basic Authentication or Oauth2).

Enter the Database configuration:

 * Host: `db`
 * User: `piwigo`
 * Password: Use the `MARIADB_PASSWORD` from your `.env_${DOCKER_CONTEXT}_default` file.
 * Database name: `piwigo`

## Upgrade

Upgrading piwigo requires two steps:

 * Update the `PIWIGO_VERSION` variable in the .env file.
 * Run the builtin updater to update the volume config files.
