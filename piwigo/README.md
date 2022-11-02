# Piwigo

[Piwigo](https://piwigo.org/) is an online photo gallery and manager.

Run `make config` to automatically configure your
`.env_${DOCKER_CONTEXT}` file. Alternatively, you can manually copy
`.env-dist` to `.env` and edit the variables accordingly:

 * `PIWIGO_TRAEFIK_HOST` the external domain name to forward from traefik.
 * `MARIADB_ROOT_PASSWORD` the root mysql password
 * `MARIADB_DATABASE` the mysql database name
 * `MARIADB_USER` the mysql database username
 * `MARIADB_PASSWORD` the mysql user password
 * `TIMEZONE` the timezone, in the format of [TZ database name](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)

Once the `.env_${DOCKER_CONTEXT}` file is configured install piwigo:

```
make install
```

Open the app:

```
make open
```

When you first start up piwigo, you must immediately configure it, as
it is left open to the world in an insecure initial state. 

Enter the Database configuration:

 * Host: `db`
 * User: `piwigo`
 * Password: Use the `MARIADB_PASSWORD` from your `.env_${DOCKER_CONTEXT}` file.
 * Database name: `piwigo`

Note that piwigo has an update mechanism builtin, that must be run
periodically; updating the docker image is insufficient.
