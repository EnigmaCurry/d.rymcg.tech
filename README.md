# d.rymcg.tech

This is a collection of docker-compose projects consisting of [Traefik](traefik)
as a TLS HTTPs/TCP proxy and other various services behind this proxy. Each
project is in its own sub-directory containing its own `docker-compose.yaml` and
`.env` file (as well as `.env-dist` sample file). This structure allows you to
pick and choose which services you wish to enable.

Uniform Makefiles exist to simplify administration. Each project sub-directory
contains a Makefile which wraps all of the configuration, installation, and
maintaince tasks for the specific project. Setup is usually as easy as `make
config`, `make install`, and then `make open`, which opens your web browser to
the newly deployed application. Under the covers, setup is pure
`docker-compose`, with *all* configuration derived from the
`docker-compose.yaml` and `.env` files.

# Contents

- [All configuration comes from the environment](#all-configuration-comes-from-the-environment)
- [Prerequisites](#prerequisites)
- [Setup](#setup)
- [Main configuration](#main-configuration)
- [Install applications](#install-applications)
- [Command line interaction](#command-line-interaction)
- [Backup .env files](#backup-env-files)

## All configuration comes from the environment

All of these projects are configured soley via environment variables written to
Docker [.env](https://docs.docker.com/compose/env-file/) files. 

The `.env` files are to be kept secret in each project directory (as they
include things like passwords and keys) and are therefore excluded from the git
repository via `.gitignore`. Each project includes a `.env-dist` file, which is
a sample that must be copied to create your own secret `.env` file and edited
according to the example. (Or run `make config` to run a setup wizard to create
the `.env` file for you by answering some questions.)

For containers that do not support environment variable configuration, a sidecar
container is included (usually called `config`) that will generate a config file
from a template including these environment variables, and is run automatically
before the main application starts up (therefore the config file is dynamically
generated each startup).

Many samples of docker-compose that you may find on the internet map native host
directories into the container paths. **Host-mounted directories are considered
an anti-pattern and will never be used in this project, unless there is a
compelling reason to do so.** For more information see [Rule 3 of the 12 factor
app philosophy](https://12factor.net/config). By following this rule, you can
use docker-compose from a remote client (like your laptop, accessing a remote
Docker server over SSH). More importantly, you can ensure that all of the
dependent files are fully contained by Docker itself, and therefore the entire
application state is managed as part of the container lifecycle.

## Prerequisites
### Create a Docker host

[Install Docker Server](https://docs.docker.com/engine/install/#server) or see
[DIGITALOCEAN.md](DIGITALOCEAN.md) for instructions on creating a Docker host on
DigitalOcean. 

### Setup DNS for your domain and Docker server

You need to bring your own internet domain name and DNS service. You will need
to create DNS type `A` (or `AAAA`) records pointing to your docker server.
Finding the instructions for creating these records is left up to the user,
since DNS platforms vary greatly, but see [DIGITALOCEAN.md](DIGITALOCEAN.md) for
an example.

It is recommended to dedicate a sub-domain for this project, and then create
sub-sub-domains for each project. This will create domain names that look like
`whoami.d.example.com`, where `whoami` is the project name, and `d` is a unique
name for the overall sub-domain representing your docker server (`d` is for
`docker`, but you can make this whatever you want).

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
you install more projects, but this lets you freely use whatever domain names
you want.

### Notes on firewall

This system does not include a network firewall of its own. You are expected to
provide this in your host networking environment. (Note: `ufw` is NOT
recommended for use with Docker, nor is any other firewall that is directly
located on the same host machine as Docker. You should prefer an external
dedicated network firewall [ie. your cloud provider, or VM host].)

All traffic flows through Traefik. The network ports you need to allow are
listed in [traefik/docker-compose.yaml](traefik/docker-compose.yaml) in the
`Entrypoints` section. You can add or remove these entrypoints as you see fit.

Depending on which services you actually install, you need to open these
(default) ports in your firewall (adapt these as you add or remove entrypoints):

   | Type   | Protocol | Port Range | Description                            |
   | ------ | -------- | ---------- | --------------------------------       |
   | SSH    | TCP      |         22 | Host SSH server                        |
   | HTTP   | TCP      |         80 | Traefik HTTP endpoint                  |
   | HTTPS  | TCP      |        443 | Traefik HTTPS (TLS) endpoint           |
   | Custom | TCP      |       2222 | Traefik Gitea SSH (TCP) endpoint       |
   | Custom | TCP      |       2223 | SFTP container SSH (TCP) (direct-map)  |
   | Custom | TCP      |       8883 | Traefik Mosquitto (TLS) endpoint       |
   | Custom | TCP      |      15820 | Wireguard (TCP) (direct-map)           |
 
See [DIGITALOCEAN.md](DIGITALOCEAN.md) for an example of setting the
DigitalOcean firewall service.

## Setup

### Install workstation tools

You need to install the following tools on your local workstation:

The only hard requirements are the `docker` client, and `docker-compose`:

 * [Install docker client](https://docs.docker.com/get-docker/) (For
   Mac/Windows, this means Docker Desktop. For Linux, this means installing the
   `Docker Engine`, but not necessarily starting the daemon; the `docker` client
   program and `ssh` is all you need on your workstation to connect to a remote
   docker server.)
 * [Install docker-compose](https://docs.docker.com/compose/install/)

There are also **optional** helper scripts and Makefiles included, that will
have some additional system package requirements (Note: these Makefiles are just
convenience wrappers for creating/modifying your `.env` files and for running
`docker-compose`, so these are not required to use if you would rather just edit
your `.env` files by hand and/or run `docker-compose` manually.):

   * Base development tools including `bash`, `make`, `sed`, `xargs`, and
     `shred`.
   * `openssl` (for generating randomized passwords)
   * `htpasswd` (for encoding passwords for Traefik Basic Authentication)
   * `jq` (for processing JSON) 
   * `xdg-open` (Used for opening the service URLs in your web-browser via `make
      open`. Don't install this if your workstation is on a server, as it
      depends on Xorg/Wayland which is an unnecessary large package install.)
   * `wireguard` (client for connecting to the [wireguard](wireguard) VPN)

On Arch Linux you can install the dependencies with: `pacman -S bash base-devel
openssl apache xdg-utils jq`

For Debian or Ubuntu run: `apt-get install bash build-essential openssl apache2-utils xdg-utils jq`

### Set Docker context

First make sure that your local user account is setup for SSH access to your
remote docker server (ie. you can ssh to the remote docker `root` account, or
any account that has been added into the `docker` group). You should setup
key-based authentication so that you don't need to enter passwords during login,
as each `docker` command will need to authenticate via SSH.

On your local worksation, create a new [Docker
context](https://docs.docker.com/engine/context/working-with-contexts/) to use
with your remote docker server (eg. named `d.example.com` with the username
`root`) over SSH:

```
docker context create d.example.com \
    --docker "host=ssh://root@ssh.d.example.com"
docker context use d.example.com
```

Now when you issue `docker` or `docker-compose` commands on your local
workstation, you will actually be controlling your remote Docker server, through
SSH.

Each time you run a `docker` command, it will create a new SSH connection, which
can be slow if you need to run several commands in a row. You can speed the
connection up by enabling SSH connection multiplexing, which starts a background
connection and makes new connections re-use the existing connection. In your
`${HOME}/.ssh/config` file, put the following (replacing `ssh.d.example.com`
with your own docker server hostname, and `root` for the user account that
controls Docker):

```
Host ssh.d.example.com
    User root
    IdentitiesOnly yes
    ControlMaster auto
    ControlPersist yes
    ControlPath /tmp/ssh-%u-%r@%h:%p
```


### Clone this repository

Choose a directory to hold the source code and configuration for your new
server, then clone this repository to that location (modify `GIT_SRC`
accordingly):

```
# Each installation needs its own separate clone of this repository.
# Choose a non-existing directory specific for your domain name:
GIT_SRC=~/git/d.example.com

git clone https://github.com/EnigmaCurry/d.rymcg.tech.git ${GIT_SRC}
cd ${GIT_SRC}
```

## Main configuration

Run the configuration wizard, and answer the questions:

```
## Run this from the root directory of the cloned source:
make config
```

(This writes the main project level variables into a file named `.env.makefile`
in the root directory, and is excluded from git via `.gitignore`)

The `ROOT_DOMAIN` variable is saved in `.env.makefile` and will form the root
domain of all of the sub-project domains, so that when you run `make config` in
any of the sub-project directories, the default (but customizable) domains will
be pre-populated with your root domain suffix.

## Install applications

Each docker-compose project has its own `README.md`. You should install
[Traefik](traefik) first, as almost all of the others depend on it. After that,
install the [whoami](whoami) container to test things are working.

Install these first:

* [Traefik](traefik) - TLS reverse proxy
* [whoami](whoami) - HTTP test service

Install these services at your leisure/preference:

* [Baikal](baikal) - a lightweight CalDAV+CardDAV server.
* [Bitwarden](bitwarden_rs) - a password manager
* [CryptPad](cryptpad) - a collaborative document and spreadsheet editor 
* [Ejabberd](ejabberd) - an XMPP (Jabber) server
* [Filestash](filestash) - a web based file manager with customizable backend storage providers
* [FreshRSS](freshrss) - an RSS reader / proxy
* [Gitea](gitea) - Git host (like self-hosted GitHub) and oauth server
* [Invidious](invidious) - a Youtube proxy
* [Jupyterlab](jupyterlab) - a web based code editing environment / reproducible research tool
* [Larynx](larynx) - a speech synthesis engine
* [Mailu](mailu) - an email service suite. Run a private mail server connected to a public relay host.
* [Matterbridge](matterbridge) - a chat room bridge (IRC, Matrix, XMPP, etc)
* [Maubot](maubot) - a matrix Bot
* [Minio](minio) - an S3 storage server
* [Mosquitto](mosquitto) - an MQTT server
* [Nextcloud](nextcloud) - a collaborative file server
* [Node-RED](nodered) - a graphical event pipeline editor
* [Piwigo](piwigo) - a photo gallery and manager
* [S3-proxy](s3-proxy) - an HTTP directory index for S3 backend
* [SFTP](sftp) - a secure file server
* [Shaarli](shaarli) - a bookmark manager
* [Syncthing](syncthing) - a multi-device file synchronization tool
* [Tiny Tiny RSS](ttrss) - an RSS reader / proxy
* [traefik-forward-auth](traefik-forward-auth) - Traefik oauth middleware
* [Websocketd](websocketd) - a websocket / CGI server
* [Wireguard](wireguard) - a simple VPN server
* [XBrowserSync](xbs) - a bookmark manager

Bespoke things:

* [certificate-ca](_terminal/certificate-ca) Experimental ad-hoc certifcate CA. Creates
  self-signed certificates for situations where you don't want to use Let's
  Encrypt.
* [Linux Shell Containers](_terminal/linux) create bash aliases that
  automatically build and run programs in Docker containers.

## Command line interaction

As alluded to earlier, this project offers two ways to control Docker:

 1. Editing `.env` files and running `docker-compose` yourself.
 2. Running `make` targets that edit the `.env` files and runs `docker-compose`
    for you.

Both of these methods are compatible, and they both get you to the same place.
The Makefiles offer a more streamlined approach with sensible defaults, and the
sub-project documentation mostly reflects this choice. Editing the .env files by
hand still offers you more control and options for experimentation.

### Using docker-compose by hand

For all of the containers that you wish to install, do the following:

 * Read the README.md file found in the sub-project directory.
 * Open your terminal and change to the project directory containing `docker-compose.yaml`
 * Copy the example `.env-dist` to `.env`
 * Edit all of the variables in `.env`
 * Follow the README for instructons to start the containers. Generally, all you
   need to do is run: `docker-compose up --build -d`

### Using the Makefiles

Alternatively, each project has a Makefile that helps to simplify configuration
and startup. You can use the Makefiles to automatically edit the `.env` files
and to start the service for you:

 * `cd` into the sub-project directory.
 * Read the README.md file.
 * Run `make config` 
 * Answer the interactive questions, and the `.env` file will be created/updated
   for you. Examples are pre-filled with default values (and based upon your
   `ROOT_DOMAIN` specified earlier). You should accept or edit these values, or
   use the backspace to clear them out entirely, and fill in your own answers.
 * Verify the configuration by looking at the contents of `.env`. 
 * Run `make install` to start the services. (this is the same thing as
   `docker-compose up --build -d`)
 * Most services have a website URL, which you can open automatically, run:
   `make open` (requires `xdg-utils`).
 * See `make help` (or just run `make`) for a list of all the other available
   targets, including `make status`, `make start`, `make stop` and `make
   destroy`. Be sure to recognize that `make` has tab completion in bash :)
 * You can also run `make status` in the root directory of the cloned source.
   This will list all of the installed applications.

## Backup .env files (optional)

Because the `.env` files contain secrets, they are to be excluded from being
committed to the git repository via `.gitignore`. However, you may still wish to
retain your configurations by making a backup. This section will describe how to
make a backup of all of your `.env` files to a GPG encrypted tarball, and how to
clean/delete all of the plain text copies.

### Setup GPG

First you will need to setup a GPG key. You can do this from the same
workstation, or from a different computer entirely:

```
# Create gpg key (note the long ID it generates, second line after 'pub'):
gpg --gen-key

# Send your key to the public keyserver:
gpg --send-keys [YOUR_KEY_ID]
```

On the workstation you cloned this repository to, import this key:

```
# Import your key from the public keyserver:
gpg --receive-keys [YOUR_KEY_ID]
```

### Create encrypted backup

From the root directory of your clone of this repository, run:

```
make backup-env
```

The script will ask to add `GPG_RECIPIENT` to your `.env.makefile`. Enter the
GPG pub key ID value for your key. 

A new encrypted backup file will be created in the same directory called
something like
`./d.example.com_environment-backup-2022-02-08--18-51-39.tgz.gpg`. The
`GPG_RECIPIENT` key is the *only* key that will be able to read this encrypted
backup.

### Clean environment files

Now that you have an encrypted backup, you may wish to delete all of the
unencryped `.env` files. Note that you will not be able to control your
docker-compose projects without the decrypted .env files, but you may restore
them from the backup at any time.

To delete all the .env files you could run:

```
## Make sure you have a backup of your .env files first:
make clean
```

### Restore .env files from backup

To restore from this backup, you will need your GPG private keys setup on your
worstation, and then run:

```
make restore-env
```

Enter the name of the backup file, and all of the `.env` files will be restored
to their original locations.
