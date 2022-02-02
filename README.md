# d.rymcg.tech

This is a collection of docker-compose projects consisting of [Traefik](traefik)
as a TLS HTTPs/TCP proxy and other various services behind this proxy. Each
project is in its own sub-directory containing its own `docker-compose.yaml` and
`.env` file (as well as `.env-dist` sample file). This structure allows you to
pick and choose which services you wish to enable.

## All configuration comes from the environment

All of these projects are configured soley via environment variables written to
[Docker env](https://docs.docker.com/compose/env-file/) files. For containers
that do not support environment variable configuration, a sidecar container is
included that will generate a config file from environment variables, which is
run automatically before each container startup.

The `.env` files are to be kept secret in each project directory (as they
include things like passwords and keys) and are therefore excluded from the git
repository via `.gitignore`. Each project includes a `.env-dist` file, which is
a sample that must be copied to create your own secret `.env` file and edited
according to the example. (Or run `make config` to run a setup wizard to create
the `.env` file for you by answering some questions.)

Many samples of docker-compose that you may find on the internet map native host
directories into the container paths. **Host-mounted directories are considered
an anti-pattern and will never be used in this project, unless there is a
compelling reason to do so.** For more information see [Rule 3 of the 12 factor
app philosophy](https://12factor.net/config). By following this rule, you can
use docker-compose from a remote client (like your laptop, accessing Docker over
SSH with the remote `DOCKER_HOST` variable set). By doing so, you can ensure
that all the dependent files are fully contained by Docker itself.

## Prerequisites
### Create a Docker host

[Install Docker Server](https://docs.docker.com/engine/install/#server) or see
[DIGITALOCEAN.md](DIGITALOCEAN.md) for instructions on creating a Docker host on
DigitalOcean. 

### Setup DNS for your domain and Docker server

You need to bring your own internet domain name and DNS service. You will need
to create DNS type `A` (or `AAAA`) records pointing to your docker server.
Finding the instructions for creating these `A` records is left up to the user,
since DNS platforms vary greatly, but see [DIGITALOCEAN.md](DIGITALOCEAN.md) for
an example.

The domain naming convention recommended to use is a sub-domain off of your main
domain, and create sub-sub-domains for each project. This will create domain
names that look like `whoami.d.example.com`, where `whoami` is the project name,
and `d` is a unique name for the overall sub-domain representing your docker
server (`d` is for `docker`, but you can make this whatever you want).

By dedicating a sub-domain for all your projects, this allows you to create a
DNS record for the wildcard: `*.d.example.com`, which will automatically direct
all sub-sub-domain requests to your docker server.

Note that you *could* put a wildcard record on your root domain, ie.
`*.example.com`, however if you did this you would not be able to use the domain
for a second instance, nor for anything else, but if you're willing to dedicate
the entire domain to this single instance, go ahead.

If you don't want to create a wildcard record, you can just create several
normal `A` (or `AAAA`) records for each of the domains your apps will use, but
this might mean that you need to come back and add several more records later as
you install more projects, and also may break some of the assumptions in the
(optional) Makefiles.

### Notes on firewall

This system does not include a network firewall of its own. You are expected to
provide this in your host networking environment. (Note: `ufw` is NOT
recommended for use with Docker, nor any other firewall directly located on the
same host machine as Docker. You should prefer an external dedicated firewall
[ie. your cloud provider], or none at all.)

All traffic flows through Traefik. The network ports you need to allow are
listed in [traefik/docker-compose.yaml](traefik/docker-compose.yaml) in the
`Entrypoints` section. You can add or remove these entrypoints as you see fit.

You need to open these (default) ports in your firewall (adapt as you add
or remove entrypoints):

   | Type   | Protocol | Port Range | Description                      |
   | ------ | -------- | ---------- | -------------------------------- |
   | SSH    | TCP      |         22 | Host SSH server                  |
   | HTTP   | TCP      |         80 | Traefik HTTP endpoint            |
   | HTTPS  | TCP      |        443 | Traefik HTTPS (TLS) endpoint     |
   | Custom | TCP      |       2222 | Traefik Gitea SSH (TCP) endpoint |
   | Custom | TCP      |       2223 | SFTP container SSH (TCP)         |
   | Custom | TCP      |       8883 | Traefik Mosquitto (TLS) endpoint |
 
See [DIGITALOCEAN.md](DIGITALOCEAN.md) for an example of setting the
DigitalOcean firewall service.

## Setup

### Install workstation tools

You need to install the following tools on your local development workstation:

The only hard requirement is the `docker` client and `docker-compose`:

 * [Install docker client](https://docs.docker.com/get-docker/) (For
   Mac/Windows, this means Docker Desktop. For Linux, this means installing the
   `Docker Engine`, but not necessarily starting the daemon; the `docker` client
   program is all you need on your workstation to connect to a remote docker
   server.)
 * [Install docker-compose](https://docs.docker.com/compose/install/)
 
There are also **optional** helper scripts and Makefiles included, that will
have some additional system package requirements (Note: these Makefiles are just
convenience wrappers for creating/modifying your `.env` files and for running
`docker-compose`, so these are not required to use if you would rather just edit
your `.env` files by hand and/or run `docker-compose` manually.):

   * Base development tools including `bash`, `make`, and `sed`:
     * On Arch Linux run `pacman -S bash base-devel`
     * On Debian/Ubuntu run `apt-get install bash build-essential`
   * `openssl` (for generating randomized passwords)
   * `xdg-open` found in the `xdg-utils` package. (Used for opening the service
     URLs in your web-browser via `make open`)

### Set Docker context

First make sure that your local user account is setup for SSH access to your
remote docker server (ie. you can ssh to the remote docker `root` account, or
any account that has been added into the `docker` group). You should setup
key-based authentication so that you don't need to enter passwords during login.

On your local worksation, create a new [Docker
context](https://docs.docker.com/engine/context/working-with-contexts/) to use
with your remote docker server (eg. named `d.example.com` with the username
`root`) over SSH:

```
docker context create d.example.com --docker "host=ssh://root@ssh.d.example.com"
docker context use d.example.com
```

Now when you issue `docker` or `docker-compose` commands on your local
workstation, you will actually be controlling your remote docker server, through
SSH.

Each time you run a `docker` command, it will create a new SSH connection, which
can be slow if you need to run multiple commands. You can speed the connection
up by enabling SSH connection multiplexing. In your `${HOME}/.ssh/config` file,
put the following (replacing `ssh.d.example.com` with your own docker server
hostname):

```
Host ssh.d.example.com
    User root
    IdentitiesOnly yes
    ControlMaster auto
    ControlPersist yes
    ControlPath /tmp/ssh-%u-%r@%h:%p
```

### Clone this repository

Clone this repository to your workstation, and change to this directory:

```
git clone https://github.com/EnigmaCurry/d.rymcg.tech.git \
   ~/git/vendor/enigmacurry/d.rymcg.tech
cd ~/git/vendor/enigmacurry/d.rymcg.tech
```

## Main configuration

Run the configuration wizard, and answer the questions:

```
## Run this from the ROOT directory of the repository d.rymcg.tech
make config
```

(This writes the main project level variables into a file named `.env.makefile`
in the root directory, and is excluded from git via `.gitignore`)

The `ROOT_DOMAIN` variable is saved in `.env.makefile` and will form the root
domain of all of the sub-project domains, so that when you run `make config` in
any of the sub-project directories, the default (but customizable) domains will
be pre-populated with your root domain.

### Create the proxy network

Since each project is in a separate docker-compose file, you must use an
external *named* Docker network to interconnect them. All this means is that you
must manually create the Docker network yourself and reference this network's
name in the compose files.

Create the new network for Traefik:

```
## Note: `make config` already ran this, but it won't hurt to do it again:
docker network create traefik-proxy
```

Each `docker-compose.yaml` file will use a similar snippet in order to connect
to Traefik:

```
### Link to the external named network traefik-proxy:
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

Each docker-compose project has its own `README.md`. You should install
[Traefik](traefik) first, as almost all of the others depend on it. After that,
install the [whoami](whoami) container to test things are working.

Install these first:

* [Traefik](traefik)
* [whoami](whoami)

If you want a git host + OAuth identity server, install these next:

* [Gitea](gitea)
* [traefik-forward-auth](traefik-forward-auth)

Install these services at your leisure/preference:

* [Baikal](baikal)
* [Bitwarden](bitwarden_rs)
* [CryptPad](cryptpad)
* [ejabberd](ejabberd)
* [FreshRSS](freshrss)
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

Extra stuff:

* [_terminal](_terminal) contains various terminal programs that don't start
  network services, but run interactively in your terminal.

## Command line interaction

As alluded to earlier, this project offers two ways to control Docker:

 1. Editing `.env` files and running `docker-compose` directly.
 2. Running `make` targets that edit the `.env` files for you, and do the same
    thing.

### Running docker-compose natively

For all of the containers that you wish to install, do the following:

 * Read the README.md file found in each project directory
 * Open your terminal and change to the project directory containing `docker-compose.yaml`
 * Copy the example `.env-dist` to `.env`
 * Edit all of the variables in `.env`
 * Follow the README for instructons to start the containers. Generally, all you
   need to do is run: `docker-compose up --build -d`

### Running with the Makefiles

Alternatively, each project has a Makefile that helps to simplify configuration
and startup. You can use the Makefiles to automatically edit the `.env` files
and to start the service for you:

 * `cd` into the project sub-directory.
 * Run `make config` 
 * Answer the interactive questions, and the `.env` file will be created/updated
   for you. Examples are pre-filled with default values (and based upon your
   `ROOT_DOMAIN` specified earlier). You should accept or edit these values, or
   use the backspace to clear them out entirely, and fill in your own answers.
 * Verify the configuration by looking at the contents of `.env`.
 * Run `make install` to start the services. (this is the same thing as
   `docker-compose up --build -d`)
 * Most services have a website URL, which you can open automatically, run:
   `make open` (after waiting a bit for the service to start).
 * See `make help` (or just `make`) for a list of all the other available
   targets, including `make status`, `make stop` and `make destroy`.
