# d.rymcg.tech

This is a docker-compose project consisting of Traefik as a TLS HTTPs/TCP proxy, and
other various services behind this proxy. Each project is in its own
sub-directory containing its own `docker-compose.yaml` and `.env` file (and
`.env-dist` sample file), this structure allows you to pick and choose which
services you wish to enable.

The `.env` files are secret, and excluded from being committed to the git
repository, via `.gitignore`. Each project includes a `.env-dist` file which is
a sample that must be copied, creating your own secret `.env` file, and edit
appropriately.

For this project, all configuration must be done via:

 * Environment variables in `.env` files (preferred)
 * Copied config files into a *named* volume (in the case that the container
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

[Install Docker Server](https://docs.docker.com/engine/install/#server) or see
[DIGITALOCEAN.md](DIGITALOCEAN.md) for instructions on creating a docker host on
DigitalOcean. Install [docker-compose](https://docs.docker.com/compose/install/)
on your workstation.

### Create the proxy network

Since each project is in separate docker-compose files, you must use an
`external/named` docker network to interconnect them. All this means, is that
you must manually create the docker network yourself, and reference this
network's name in the compose files. (`external` means that docker-compose will
not attempt to create nor destroy this network like it usually would if it were
created by docker-compose)

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
    ## Connect to the Traefik proxy network (allows it to be exposed publicly):
    - traefik-proxy
    ## If there are additional containers for the backend,
    ## also connect to the default (not exposed) network:
    ## You only need to specify the default network when you have more than one.
    - default
```

## Install desired containers

Each docker-compose project has its own README. You should install Traefik
first, as almost all of the others depend on it.

* [Traefik](traefik)
* [Gitea](gitea)
* [Tiny Tiny RSS](ttrss)
* [Baikal](baikal)
* [Nextcloud](nextcloud)
* [CryptPad](cryptpad)
* [Node-RED](nodered)
* [Mosquitto](mosquitto)
* [Bitwarden](bitwarden_rs)
* [Shaarli](shaarli)
* [xBrowserSync](xbs)
* [Piwigo](piwigo)
* [SFTP](sftp)
* [Syncthing](syncthing)
* [Jupyterlab](jupyterlab)
* [Larynx](larynx)
* [Maubot](maubot)
* [certificate-ca and cert-manager.sh](certificate-ca)
* [ejabberd](ejabberd)
* [websocketd](websocketd)

For all containers you wish to install, do the following:

 * Read the README.md file found in each project directory.
 * Open your terminal, change to the project directory containing `docker-compose.yaml`
 * Copy `.env-dist` to `.env`
 * Edit all the variables in `.env`
 * Follow the README for instructons to start the container. Generally, all you
   need to do is run: `docker-compose up --build -d`
