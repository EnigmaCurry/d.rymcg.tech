# Piwigo

[Piwigo](https://piwigo.org/) is an online photo gallery and manager.

Run `make config` to automatically configure your
`.env_${DOCKER_CONTEXT}_default` file. 

This will ask you to enter the domain name to use, and whether or not
you want to configure a username/password via HTTP Basic Authentication.
It automatically saves your responses into the configuration file
`.env_{INSTANCE}`.

It will also ask if you want to use OpenID/OAuth2 authentication. 
Using OpenID/OAuth2 will require a login to access your app, but it will not
affect what a successfully logged-in person can do in your app. If your app has
a built-in authorization mechanism that can check for the user header that
traefik-forward-auth sends, then your app can limit what the logged-in person
can do in the app. But if your app can't check the user header, or if your app
doesn't have built-in authorization at all, then any person with an account
on your Gitea server can log into your app and have full acces

Alternatively to running `make config`, you can manually copy
`.env-dist` to `.env_${DOCKER_CONTEXT}_default` and edit the variables accordingly:

 * `PIWIGO_TRAEFIK_HOST` the external domain name to forward from traefik.
 * `MARIADB_ROOT_PASSWORD` the root mysql password
 * `MARIADB_DATABASE` the mysql database name
 * `MARIADB_USER` the mysql database username
 * `MARIADB_PASSWORD` the mysql user password
 * `TIMEZONE` the timezone, in the format of [TZ database name](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)
 * `PIWIGO_OAUTH2` set to `yes` to configure Oauth2 authentication (in addition to Piwigo's own internal authentication)
 * `PIWIGO_HTTP_AUTH` it's easiest to configure this variable via `make config`, but you can manually enter 1 or more credentials in the format `<username>:<password hashed by htpasswd>[,<username2>:<htpasswd-hashed password 2>...]`

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
