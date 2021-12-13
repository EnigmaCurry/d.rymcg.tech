# Piwigo

[Piwigo](https://piwigo.org/) is an online photo gallery and manager.

Copy `.env-dist` to `.env` and edit the variables accordingly:

 * `PIWIGO_TRAEFIK_HOST` the external domain name to forward from traefik.
 * `MARIADB_ROOT_PASSWORD` the root mysql password
 * `MARIADB_DATABASE` the mysql database name
 * `MARIADB_USER` the mysql database username
 * `MARIADB_PASSWORD` the mysql user password
 * `TIMEZONE` the timezone, in the format of [TZ database name](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)

To start piwigo, go into the piwigo directory and run `docker-compose up -d`.

When you first start up piwigo, you must immediately configure it, as it is left
open to the world. The database hostname is `db`, which is the name of the
service listed in the docker-compose file.

Note that piwigo has an update mechanism builtin, that must be run periodically,
in addition to updating the docker container image.

