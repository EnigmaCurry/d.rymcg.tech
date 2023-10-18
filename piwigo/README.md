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
