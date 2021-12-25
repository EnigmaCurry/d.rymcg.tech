# d.rymcg.tech

This is a collection of docker-compose projects consisting of
[Traefik](https://doc.traefik.io/traefik/) as a TLS HTTPs/TCP proxy and other
various services behind this proxy. Each project is in its own sub-directory
containing its own `docker-compose.yaml` and `.env` file (as well as `.env-dist`
sample file). This structure allows you to pick and choose which services you
wish to enable.

For this project, all configuration must be done via:

 * Environment variables in the `.env` files (preferred)
 * Generated or copied config files into a *named* volume (in the case that the
   container doesn't support environment variables)

The `.env` files are kept secret (as they include things like passwords and
keys) and are excluded from the git repository via `.gitignore`. Each project
includes a `.env-dist` file, which is a sample that must be copied to create
your own secret `.env` file and edited according to the example.

Many samples of docker-compose that you may find on the internet map native host
directories into the container paths. **Host-mounted directories are considered
an anti-pattern and will never be used in this project, unless there is a
compelling reason to do so.** For more information see [Rule 3 of the 12 factor
app philosophy](https://12factor.net/config). By following this rule, you can
use docker-compose from a remote client (like your laptop, accessing Docker over
SSH with the remote `DOCKER_HOST` variable set). By doing so, you can ensure
that all the dependent files are fully contained by Docker itself.

## Setup
### Create a Docker host

[Install Docker Server](https://docs.docker.com/engine/install/#server) or see
[DIGITALOCEAN.md](DIGITALOCEAN.md) for instructions on creating a Docker host on
DigitalOcean. Install [docker-compose](https://docs.docker.com/compose/install/)
on your workstation.

### Create the proxy network

Since each project is in a separate docker-compose file, you must use an
external *named* Docker network to interconnect them. All this means is that you
must manually create the Docker network yourself and reference this network's
name in the compose files.

Create the new network for Traefik:

```
docker network create traefik-proxy
```

Each docker-compose file will use a similar snippet in order to connect to
Traefik:

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

 * Read the README.md file found in each project directory
 * Open your terminal, change to the project directory containing `docker-compose.yaml`
 * Copy `.env-dist` to `.env`
 * Edit all the variables in `.env`
 * Follow the README for instructons to start the container. Generally, all you
   need to do is run: `docker-compose up --build -d`
