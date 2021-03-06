# d.rymcg.tech

This is a collection of docker-compose projects consisting of
[Traefik](https://doc.traefik.io/traefik/) as a TLS HTTP/TCP reverse proxy and
other various applications and services behind this proxy. Each project is in
its own sub-directory containing its own `docker-compose.yaml` and `.env` file
(as well as `.env-dist` sample file). This structure allows you to pick and
choose which services you wish to enable.

Each project has a `Makefile` to simplify configuration, installation, and
maintainance tasks. Setup is usually as easy as: `make config`, answer some
questions, `make install`, and then `make open`, which opens your web browser to
the newly deployed application. Under the covers, setup is pure
`docker-compose`, with *all* configuration derived from the `.env` file.

# Contents

- [All configuration comes from the environment](#all-configuration-comes-from-the-environment)
- [Prerequisites](#prerequisites)
- [Setup](#setup)
- [Main configuration](#main-configuration)
- [Install applications](#install-applications)
- [Command line interaction](#command-line-interaction)
- [Backup .env files](#backup-env-files-optional)

If you're impatient, or have read all of this before, you can follow
[BRIEF.md](BRIEF.md) for a quicker introduction.

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

This project stores all application data in Docker named volumes. Many samples
of docker-compose that you may find out there on the internet, will map native
host directories into their container paths. **Host-mounted directories are
considered an anti-pattern and will never be used in this project, unless there
is a compelling reason to do so.** For more information see [Rule 3 of the 12
factor app philosophy](https://12factor.net/config). By following this rule, you
can use docker-compose from a remote client (like your laptop, accessing a
remote Docker server over SSH). More importantly, you can ensure that all of the
dependent files are fully contained by Docker itself, and therefore the entire
application state is managed as part of the container lifecycle.

## Prerequisites
### Create a Docker host

[Install Docker Server](https://docs.docker.com/engine/install/#server) on your
own public internet server or cloud host.

See [DIGITALOCEAN.md](DIGITALOCEAN.md) for instructions on creating a Docker
host on DigitalOcean. 

For development purposes, you can install Docker on a virtual machine (and
remotely control it from your local workstation). See [_docker_vm](_docker_vm#readme)
to install Docker on KVM/Qemu.

### Setup DNS for your domain and Docker server

You need to bring your own internet domain name and DNS service. You will need
to create DNS type `A` (or `AAAA`) records pointing to your docker server. There
are many different DNS platforms that you can use, but see
[DIGITALOCEAN.md](DIGITALOCEAN.md) for an example.

It is recommended to dedicate a sub-domain for this project, and then create
sub-sub-domains for each application. This will create domain names that look
like `whoami.d.example.com`, where `whoami` is the application name, and `d` is
a unique name for the overall sub-domain representing your docker server (`d` is
for `docker`, but you can make this whatever you want).

By dedicating a sub-domain for all your projects, this allows you to create a
DNS record for the wildcard: `*.d.example.com`, which will automatically direct
all sub-sub-domain requests to your docker server.

Note that you *could* put a wildcard record on your root domain, ie.
`*.example.com`, however if you did this you would not be able to use the domain
for a second instance, but if you're willing to dedicate the entire domain to
this single instance, go ahead. 

If you don't want to create a wildcard record, you can just create several
normal `A` (or `AAAA`) records for each of the domains your apps will use, but
this might mean that you need to come back and add several more records later as
you install more projects, (and complicate the ACME/Let's Encrypt process) but
this would let you freely use whatever domain names you want.

### Notes on firewall

This system does not include a network firewall of its own. You are expected to
provide this in your host networking environment. (Note: `ufw` is NOT
recommended for use with Docker, nor is any other firewall that is directly
located on the same host machine as Docker. You should prefer an external
dedicated network firewall [ie. your cloud provider, or VM host]. If you have no
other option but to run the firewall on the same host, check out
[chaifeng/ufw-docker](https://github.com/chaifeng/ufw-docker#solving-ufw-and-docker-issues)
for a partial fix.)

With a few exceptions, all network traffic flows through Traefik. The network
ports that you need to allow through the firewall are listed in
[traefik/docker-compose.yaml](traefik/docker-compose.yaml) in the `Entrypoints`
section. You can add or remove these entrypoints as you see fit.

Depending on which services you actually install, you need to open these
(default) ports in your firewall:

   | Type   | Protocol | Port Range | Description                           |
   | ------ | -------- | ---------- | --------------------------------      |
   | SSH    | TCP      |         22 | Host SSH server (direct-map)          |
   | HTTP   | TCP      |         80 | Traefik HTTP endpoint                 |
   | TLS    | TCP      |        443 | Traefik HTTPS (TLS) endpoint          |
   | SSH    | TCP      |       2222 | Traefik Gitea SSH (TCP) endpoint      |
   | SSH    | TCP      |       2223 | SFTP container SSH (TCP) (direct-map) |
   | TLS    | TCP      |       5432 | PostgreSQL DBaaS (direct-map)         |
   | TLS    | TCP      |       8883 | Traefik MQTT (TLS) endpoint           |
   | VPN    | TCP      |      15820 | Wireguard (TCP) (direct-map)          |
   | WebRTC | UDP      |      10000 | Jitsi Meet video bridge (direct-map)  |

The ports that are listed as `(direct-map)` are not connected to Traefik, but
are directly exposed (public) to the docker host network.

For a minimal installation, you only need to open ports 22 and 443. This would
enable all of the web-based applications to work, except for the ones that need
an additional port, as listed above.

See [DIGITALOCEAN.md](DIGITALOCEAN.md) for an example of setting the
DigitalOcean firewall service.

## Setup

### Install workstation tools

You need to install the following tools on your local workstation:

 * [Install docker client](https://docs.docker.com/get-docker/) (For
   Mac/Windows, this means Docker Desktop. For Linux, this means installing the
   Docker Engine, but not necessarily starting the daemon; the `docker` client
   program and `ssh` are all you need installed on your workstation to connect
   to a remote docker server.)
 * [Install docker-compose
   v2.x](https://docs.docker.com/compose/cli-command/#installing-compose-v2)
   (For Docker Desktop, `docker-compose` is already installed. For Linux, it is
   a separate installation.)

### Install optional workstation tools

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
   * `xdg-open` (Used for automatically opening the service URLs in your
      web-browser via `make open`. Don't install this if your workstation is on
      a headless server, as it depends on Xorg/Wayland. Without `xdg-open`, this
      will degrade to simply printing the URL to copy and paste.)
   * `wireguard` (client for connecting to the [wireguard](wireguard) VPN)

On Arch Linux you can install these dependencies with: `pacman -S bash base-devel
openssl apache xdg-utils jq wireguard-tools`

For Debian or Ubuntu run: `apt-get install bash build-essential openssl
apache2-utils xdg-utils jq wireguard`

### Setup SSH access to the server

Make sure that your local workstation user account is setup for SSH access to
the remote docker server (ie. you should be able to ssh to the remote docker
`root` account, or another account that has been added into the `docker` group).
You should setup key-based authentication so that you don't need to enter
passwords during login, as each `docker` command will need to authenticate via
SSH.

 * See the general article [How to Set Up SSH
   Keys](https://www.digitalocean.com/community/tutorials/how-to-set-up-ssh-keys-2)
 * Make sure to turn off regular password authentication, set
   `PasswordAuthentication no` in the server config.
 * If your workstation's operating system does not automatically provide an
   ssh-agent (to make it so you don't have to keep typing your key's
   passphrase), check out
   [Keychain](https://wiki.archlinux.org/title/Keychain#Keychain) for an easy
   solution.

When set for a remote Docker context, the `docker` command will create a new SSH
connection for each time it is run. This can be especially slow for running
several commands in a row. You can speed the connection time up, by enabling SSH
connection multiplexing, which starts a single background connection and makes
new connections re-use this existing connection. 

On your workstation, create or edit your existing `${HOME}/.ssh/config` file.
Add the following configuration (replacing `ssh.d.example.com` with your own
docker server hostname, and `root` for the user account that controls Docker):

```
Host ssh.d.example.com
    User root
    IdentitiesOnly yes
    ControlMaster auto
    ControlPersist yes
    ControlPath /tmp/ssh-%u-%r@%h:%p
```

(The hostname `ssh.d.example.com` relies upon the wildcard `*.d.example.com` or
an explicit `A` record having been created for this hostname.)

### Set remote Docker context

On your local workstation, create a new [Docker
context](https://docs.docker.com/engine/context/working-with-contexts/) to use
with your remote docker server (eg. named `d.example.com`) over SSH:

```
docker context create d.example.com \
    --docker "host=ssh://ssh.d.example.com"
docker context use d.example.com
```

(To benefit from connection multiplexing, make sure to use the exact Host name
[`ssh.d.exmaple.com`] that you specified in your `${HOME}/.ssh/config`)

Now whenever you issue `docker` or `docker-compose` commands on your local
workstation, you will actually be controlling your remote Docker server, through
SSH, and you can easily switch contexts between multiple server backends.


### Clone this repository to your workstation

```
git clone https://github.com/EnigmaCurry/d.rymcg.tech.git \
    ${HOME}/git/vendor/enigmacurry/d.rymcg.tech
cd ${HOME}/git/vendor/enigmacurry/d.rymcg.tech
```

## Main configuration

Run the configuration wizard, and answer the questions:

```
## Run this from the root source directory:
make config
```

(This writes the main project level variables into a file named
`.env_${DOCKER_CONTEXT}` in the root source directory, based upon the name of
the current Docker context. This file is excluded from the git repository via
`.gitignore`.)

The `ROOT_DOMAIN` variable is saved in `.env_${DOCKER_CONTEXT}` and will serve
as the default root domain of all of the sub-project domains, so that when you
run `make config` in any of the sub-project directories, the default (yet
customizable) domain will be pre-populated with your root domain suffix.

You can have multiple `.env_${DOCKER_CONTEXT}` files, one for each Docker
server, named after the associated Docker context. To switch the current .env
file being used, change the Docker context:

```
docker context use {CONTEXT}
```

## Install applications

Each docker-compose project has its own `README.md`. You should install
[Traefik](traefik) first, as almost all of the others depend on it. After that,
install the [whoami](whoami) container to test that things are working
correctly.

Install these first:

* [Traefik](traefik) - HTTP / TLS / TCP / UDP reverse proxy
* [Whoami](whoami) - HTTP test service

Install these services at your leisure/preference:

* [ArchiveBox](archivebox) - a website archiving tool
* [Baikal](baikal) - a lightweight CalDAV+CardDAV server
* [Bitwarden](bitwarden_rs) - a password manager
* [CryptPad](cryptpad) - a collaborative document and spreadsheet editor 
* [Ejabberd](ejabberd) - an XMPP (Jabber) server
* [Filestash](filestash) - a web based file manager with customizable backend storage providers
* [FreshRSS](freshrss) - an RSS reader / proxy
* [Gitea](gitea) - Git host (like self-hosted GitHub) and oauth server
* [Invidious](invidious) - a Youtube proxy
* [Jitsi Meet](jitsi-meet) - a video conferencing and screencasting service
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
* [PostgreSQL](postgresql) - a database server configured with mutual TLS authentication for public networks
* [PrivateBin](privatebin) - a minimal, encrypted, zero-knowledge, pastebin
* [Rdesktop](rdesktop) - a web based remote desktop (X11) in a container
* [S3-proxy](s3-proxy) - an HTTP directory index for S3 backend
* [SFTP](sftp) - a secure file server
* [Shaarli](shaarli) - a bookmark manager
* [Syncthing](syncthing) - a multi-device file synchronization tool
* [Thttpd](thttpd) - a tiny/turbo/throttling HTTP server for serving static files
* [Tiny Tiny RSS](ttrss) - an RSS reader / proxy
* [Traefik-forward-auth](traefik-forward-auth) - Traefik oauth middleware
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
The Makefiles offer a more streamlined approach with a configuration wizard and
sensible defaults. Most of the sub-project README files reflects the Makefile
style for config. Editing the .env files by hand still offers you more control,
and options for experimentation, and is always available.

### Using docker-compose by hand

For all of the containers that you wish to install, do the following:

 * Read the README.md file found in the sub-project directory.
 * Open your terminal and `cd` to the project directory containing
   `docker-compose.yaml`
 * Copy the example `.env-dist` to `.env`
 * Edit all of the variables in `.env` according to the example and comments.
 * Follow the README for instructons to start the containers. Generally, all you
   need to do is run: `docker-compose up --build -d`

When using `docker-compose` by hand, it uses the `.env` file name by default.
You can change this behaviour by specifying the `--env-file` argument.

### Using the Makefiles

Alternatively, each project has a Makefile that helps to simplify configuration
and startup. You can use the Makefiles to automatically edit the `.env` files
and to start the service for you:

 * `cd` into the sub-project directory.
 * Read the README.md file.
 * Run `make config` 
 * Answer the interactive questions, and the `.env_${DOCKER_CONTEXT}` file will
   be created/updated for you. Examples are pre-filled with default values (and
   based upon your `ROOT_DOMAIN` specified earlier). You can accept the
   suggested default value, or use the backspace key and edit the value, to fill
   in your own answers.
 * Verify the configuration by looking at the contents of
   `.env_${DOCKER_CONTEXT}` (named with your current docker context).
 * Run `make install` to start the services. (this is the same thing as
   `docker-compose up --build -d`)
 * Most services have a website URL, which you can open automatically, run:
   `make open` (requires `xdg-utils`).
 * See `make help` (or just run `make`) for a list of all the other available
   targets, including `make status`, `make start`, `make stop` and `make
   destroy`. Be sure to recognize that `make` has tab completion in bash :)
 * You can also run `make status` in the root directory of the cloned source.
   This will list all of the installed applications.

`make config` *does not literally* create a file named `.env`, but rather one
based upon the current docker context: `.env_${DOCKER_CONTEXT}`. This allows for
different configurations to coexist in the same directory. All of the makefile
commands operate assuming this contextual environment file name, not `.env`. To
switch between configs, you switch your current docker context: `docker context
use {CONTEXT}`.

During `make config`, you will sometimes be asked to create HTTP Basic
Authentication passwords, and these passwords can be *optionally* saved into a
file named `passwords.json` inside the sub-project directory. This file is a
convenience, so that you can remember the passwords that you create.
**`passwords.json` is stored in plain text**, and excluded from being checked
into git via `.gitignore`. When you run `make open` the username and password
stored in this file is automatically applied to the URL that the browser is
asked to open, thus logging you into the admin account automatically. To delete
all of the passwords.json files, you can run `make delete-passwords` in the root
directory of this project (or `make clean` which will delete the `.env` files
too).

## Backup .env files (optional)

Because the `.env` files contain secrets, they are to be excluded from being
committed to the git repository via `.gitignore`. However, you may still wish to
retain your configurations by making a backup. This section will describe how to
make a backup of all of your `.env` and `passwords.json` files to a GPG
encrypted tarball, and how to clean/delete all of the plain text copies.

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

The script will ask to add `GPG_RECIPIENT` to your `.env_${DOCKER_CONTEXT}`.
Enter the GPG pub key ID value for your key.

A new encrypted backup file will be created in the same directory called
something like
`./${DOCKER_CONTEXT}_environment-backup-2022-02-08--18-51-39.tgz.gpg`. The
`GPG_RECIPIENT` key is the *only* key that will be able to read this encrypted
backup file.

### Clean environment files

Now that you have an encrypted backup, you may wish to delete all of the
unencryped `.env` files. Note that you will not be able to control your
docker-compose projects without the decrypted .env files, but you may restore
them from the backup at any time.

To delete all the .env files, you could run:

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

Enter the name of the backup file, and all of the `.env` and `passwords.json`
files will be restored to their original locations.
