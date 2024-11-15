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
 * `PIWIGO_OAUTH2_AUTHORIZED_GROUP` the name of an authorization group that you a created when you ran `make groups` in the `traefik` directory
 * `PIWIGO_HTTP_AUTH` it's easiest to configure this variable via `make config`, but you can manually enter 1 or more credentials in the format `<username>:<password hashed by htpasswd>[,<username2>:<htpasswd-hashed password 2>...]`

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external authentication on
top of your app.


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
