# d.rymcg.tech

This is a collection of docker-compose projects consisting of [Traefik](traefik)
as a TLS HTTPs/TCP proxy and other various services behind this proxy. Each
project is in its own sub-directory containing its own `docker-compose.yaml` and
`.env` file (as well as `.env-dist` sample file). This structure allows you to
pick and choose which services you wish to enable.

## All configuration comes from the environment

All projects are configured soley via environment variables written to [Docker
env](https://docs.docker.com/compose/env-file/) files. For containers that do
not support environment variable configuration, a sidecar container is included
that will generate a config file from environment variables, which is run
automatically before each container startup.

The `.env` files are to be kept secret (as they include things like passwords
and keys) and are therefore excluded from the git repository via `.gitignore`.
Each project includes a `.env-dist` file, which is a sample that must be copied
to create your own secret `.env` file and edited according to the example.

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
DigitalOcean. 

### Install workstation tools

You also need to install the following tools on your local workstation:

 * [docker-compose](https://docs.docker.com/compose/install/)
 * Optional: If you wish to use the Makefiles, you must install base development
   tools including GNU Bash, Make, and sed.
   * On Arch Linux run `pacman -S bash base-devel`
   * On Debian/Ubuntu run `apt-get install bash build-essential`
   * Note: The Makefiles are just a convenience wrapper, and are not required to
     use if you just want to edit your `.env` files by hand and/or run
     `docker-compose` manually.
     
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

Each docker-compose project has its own README. You should install
[Traefik](traefik) first, as almost all of the others depend on it. After that,
install the [whoami](whoami) container to test things are working.

Install these first:

* [Traefik](traefik)
* [whoami](whoami)

If you want a git host + OAuth identity server, install these next:

* [Gitea](gitea)
* [traefik-forward-auth](traefik-forward-auth)

Install these at your leisure/preference:

* [Baikal](baikal)
* [Bitwarden](bitwarden_rs)
* [CryptPad](cryptpad)
* [ejabberd](ejabberd)
* [Invidious](invidious)
* [Jupyterlab](jupyterlab)
* [Larynx](larynx)
* [Maubot](maubot)
* [minio](minio)
* [Mosquitto](mosquitto)
* [Nextcloud](nextcloud)
* [Node-RED](nodered)
* [Piwigo](piwigo)
* [s3-proxy](s3-proxy)
* [SFTP](sftp)
* [Shaarli](shaarli)
* [Syncthing](syncthing)
* [Tiny Tiny RSS](ttrss)
* [websocketd](websocketd)
* [xBrowserSync](xbs)

Bespoke things:

* [traefik-htpasswd](traefik-htpasswd)
* [experimental ad-hoc certifcate CA](certificate-ca)

For all of the containers that you wish to install, do the following:

 * Read the README.md file found in each project directory
 * Open your terminal and change to the project directory containing `docker-compose.yaml`
 * Copy the example `.env-dist` to `.env`
 * Edit all of the variables in `.env`
 * Follow the README for instructons to start the containers. Generally, all you
   need to do is run: `docker-compose up --build -d`

