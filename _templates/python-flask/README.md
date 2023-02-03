# Example Flask docker compose project

## Setup

This example project integrates with
[d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech#readme).
Before proceeding, you must first clone and setup `d.rymcg.tech` on
your workstation.

This project is an example of a so-called
["external"](https://github.com/enigmacurry/d.rymcg.tech#integrating-external-projects)
project to `d.rymcg.tech`, as it does not live in the same source tree
as `d.rymcg.tech`, but makes a link to inherit its Makefiles and to
gain its superpowers.

## Configure

Once
[d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech#readme) has
been installed, you can come back to this directory.

Run:

```
make config
```

This will create the `.env_{DOCKER_CONTEXT}` configuration file for
your service.

## Install

Run:

```
make install
```

## Open in your web browser

Run:

```
make open
```

## Development mode

If you turn on development mode in the config, the volume will start
attached to the `development` volume. You can edit the source files
locally, and rsync changes to this volume automatically. The server
will detect the new files and automatically restart.

To start the synchronization process, run:

```
make dev-sync
```

## Local Database

To access the database directly from your workstation, run:

```
make localdb
```

This starts an SSH tunnel to the postgres port inside the container,
enters you into a BASH subshell, and sets all of the environment
variables to accessing the database using local postgres tools and
clients.

On Arch linux, you want to install the postgres client package: `sudo pacman -S postgresql-libs`

On Ubuntu: `sudo apt-get install -y postgresql-client`

Inside the `make localdb` shell, you can run any of the standard
postgresql client tools: `psql`, `createdb`, `createuser`, `pg_dump`,
etc. The user credentials are pre-set in your environment for easy
access.

Notice the PGPORT setting. When using the tunnel, this port is on
`localhost`. You can use any other postgresql client connecting to
`localhost` on the given port. By default the port is randomly chosen
upon entering the subshell. To get the same port everytime, add it as
an argument:

```
## Specify a static TCP port:
make localdb PGPORT=55542
```

Keep this shell open, and you can use graphical client like
[DBeaver](https://dbeaver.io/) (when creating the connection in
DBeaver make sure to copy all the settings for host, port, database,
user, and password, as shown in the subshell session.)

## Instantiation

If you wish to run more than one instance of the app on the same
docker host, you can use `make instance`. Follow the the main
[d.rymcg.tech instantiation
docs](https://github.com/EnigmaCurry/d.rymcg.tech#creating-multiple-instances-of-a-service)
for details.

Each instance is a separate stack. Each separate instance has:

 * Its own `.env_{DOCKER_CONTEXT}_{INSTANCE_NAME}` config file.
 * Its own frontend, API, database, etc. services.
 * It's own domain name.

In the `.env_{DOCKER_CONTEXT}_{INSTANCE_NAME}` config file, each
instance has set a unique `{PROJECT}_INSTANCE` variable. This variable
is used to make discrete Traefik services, routes, and middlewares,
separate for each instance.

This could be useful for having a "production" and "development"
instance on the same box (at the risk of the integrity of the
"production" instance, if you choose to do this).
