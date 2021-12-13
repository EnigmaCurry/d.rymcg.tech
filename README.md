# d.rymcg.tech

This is a docker-compose project consisting of Traefik as a TLS HTTPS proxy, and
other various services behind this proxy. Each project is in its own
sub-directory containing its own `docker-compose.yaml` and `.env` file (and
`.env-dist` sample file), this structure allows you to pick and choose which
services you wish to enable.

The `.env` files are secret, and excluded from being committed to the git
repository, via `.gitignore`. Each project includes a `.env-dist` file which is
a sample that must be copied, creating your own secret `.env` file, and edit
appropriately.

For this project, all configuration must be done via:

 * Environment variables (preferred)
 * Copied config files into a named volume (in the case that the container
   doesn't support env variables)

Many examples of docker-compose that you may find on the internet will have host
mounted files, which allows containers to access files directly from the host
filesystem. **Host mounted files are considered an anti-pattern and will never
be used in this project.** For more information see [Rule 3 of the 12 factor app
philosophy](https://12factor.net/config). By following this rule, you can safely
use docker-compose from a remote client (over SSH with the `DOCKER_HOST`
variable set) and by doing so, you can ensure you are working with a clean state
on the host.

## Setup
### Create a docker host

[Install docker Server](https://docs.docker.com/engine/install/#server) or see
[DIGITALOCEAN.md](DIGITALOCEAN.md) for instructions on creating a docker host on
DigitalOcean.

### Create the proxy network

Since each project is in separate docker-compose files, you must use an
`external` docker network. All this means is that you manually create the
network yourself and reference this network in the compose files. (`external`
means that docker-compose will not attempt to create nor destroy this network
like it usually would.)

Create the new network for Traefik, as well as all of the apps that will be
proxied:

```
docker network create traefik-proxy
```

Each docker-compose file will use this snippet in order to connect to traefik:

```
networks:
  traefik-proxy:
    name: traefik-proxy

service:
  APP_NAME:
    networks:
    ## Connect to the Traefik proxy network (allows to be exposed):
    - traefik-proxy
    ## If there are additional containers for the backend,
    ## also connect to the default (not exposed) network:
    - default
```

## Install desired containers

Each docker-compose project has its own README. You should install Traefik
first, as almost all of the others depend on it.

* [Traefik](traefik/README.md)
* [Gitea](gitea/README.md)
* [Tiny Tiny RSS](ttrss/README.md)
* [Baikal](baikal/README.md)
* [Nextcloud](nextcloud/README.md)
* [CryptPad](cryptpad/README.md)
* [Node-RED](nodered/README.md)
* [Mosquitto](mosquitto/README.md)
* [Bitwarden](bitwarden_rs/README.md)
* [Shaarli](shaarli/README.md)
* [xBrowserSync](xbs/README.md)
* [Piwigo](piwigo/README.md)
* [SFTP](sftp/README.md)
* [Syncthing](syncthing/README.md)
* [Jupyterlab](jupyterlab/README.md)
* [Larynx](larynx/README.md)
* [Maubot](maubot/README.md)
* [ejabberd](ejabberd/README.md)

