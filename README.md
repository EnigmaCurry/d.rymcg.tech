# d.rymcg.tech

This is a collection of docker-compose projects consisting of
[Traefik](https://doc.traefik.io/traefik/) as a TLS HTTP/TCP reverse
proxy and other various applications and services behind this proxy.
Each project is in its own sub-directory containing its own
`docker-compose.yaml` and `.env` file (as well as `.env-dist` sample
file). This structure allows you to pick and choose which services you
wish to enable. You may also integrate your own external
docker-compose projects into this framework.

Each project also has a `Makefile` to simplify configuration,
installation, and maintainance tasks. The setup for any sub-project is
as easy as running:

 * `make config` and interactively answering some questions to
   generate the `.env` file automatically.
 * `make install` to deploy the service containers.
 * `make open` to automatically open your web browser to the newly
   deployed application URL.

Under the covers, setup is pure `docker-compose`, with *all*
configuration derived from the `.env` file.

# Contents

- [All configuration comes from the environment](#all-configuration-comes-from-the-environment)
- [Prerequisites](#prerequisites)
- [Setup](#setup)
- [Main configuration](#main-configuration)
- [Install applications](#install-applications)
- [Command line interaction](#command-line-interaction)
- [Creating multiple instances of a service](#creating-multiple-instances-of-a-service)
- [Backup .env files](#backup-env-files-optional)
- [Integrating external projects](#integrating-external-projects)

## All configuration comes from the environment

All of these projects are configured soley via environment variables
written to Docker [.env](https://docs.docker.com/compose/env-file/)
files.

The `.env` files are to be kept secret in each project directory
(because they include things like passwords and keys) and are
therefore excluded from the git repository via `.gitignore`. Each
project includes a `.env-dist` file, which is a sample that must be
copied to create your own secret `.env` file and edited according to
the example. (Or run `make config` to run a setup wizard to create the
`.env` file for you by answering some questions interactively.)

For containers that do not support environment variable configuration,
a sidecar container is included (usually called `config`) that will
generate a config file from a template including these environment
variables, and is run automatically before the main application starts
up (therefore the config file is dynamically generated at each
startup).

This project stores all application data in Docker **named volumes**.
Many samples of docker-compose that are written by other people, and
that you may find out there on the internet, will map native host
directories into their container paths. **Host-mounted directories are
considered an anti-pattern and will never be used in this project,
unless there is a compelling reason to do so.** For more information
see [Rule 3 of the 12 factor app
philosophy](https://12factor.net/config). By following this rule, you
can use Docker from a remote client (like your laptop, accessing a
remote Docker server over SSH). More importantly, you can ensure that
all of the dependent files are fully contained by Docker itself
(`/var/lib/docker/volumes/...`), and therefore the entire application
state is managed as part of the container/volume lifecycle.

## Prerequisites
### Create a Docker host

[Install Docker
Server](https://docs.docker.com/engine/install/#server) on your own
public internet server or cloud host.

See [SECURITY.md](SECURITY.md) for a list of security concerns when
choosing a hosting provider.

As one example, see [DIGITALOCEAN.md](DIGITALOCEAN.md) for
instructions on creating a secure Docker host on DigitalOcean.

If you need a semi-private development or staging server, and want to
be able to share some public URLs for your services, you can protect
your services by turning on Traefik's [HTTP Basic
Authentication](https://doc.traefik.io/traefik/middlewares/http/basicauth/)
or
[IPWhitelist](https://doc.traefik.io/traefik/middlewares/http/ipwhitelist/)
middlewares (see
[s3-proxy](https://github.com/EnigmaCurry/d.rymcg.tech/blob/f77aaaa5a2705eedaf29a4cdc32f91cdb65e66f7/s3-proxy/docker-compose.yaml#L35-L41)
for an example that uses both of these) or you can make an exclusively
private Traefik service with a
[Wireguard](https://github.com/EnigmaCurry/d.rymcg.tech/tree/master/traefik#wireguard-vpn)
VPN.

For local development purposes, you can install Docker in a virtual
machine (and remotely control it from your local workstation), this
ensures that you use your development environment the same way as you
would a production server. See [_docker_vm](_docker_vm#readme) for
details on how and why to install Docker in KVM/Qemu. You can also
install [Docker Desktop](https://docs.docker.com/desktop) on Linux,
Windows, or Mac (although Docker Desktop is a bit less secure than our
bespoke [_docker_vm](_docker_vm#readme)).


### Setup DNS for your domain and Docker server

You need to bring your own internet domain name and DNS service. You
will need to create DNS type `A` records (or `AAAA` records if using
IPv6) pointing to your docker server. There are many different DNS
platforms that you can use, but see [DIGITALOCEAN.md](DIGITALOCEAN.md)
for one example.

It is recommended to dedicate a sub-domain for this project, and then
create sub-sub-domains for each application. This will create domain
names that look like `whoami.d.example.com`, where `whoami` is the
application name, and `d` is a unique name for the overall sub-domain
representing your docker server (`d` is for `docker`, but you can make
this whatever you want).

By dedicating a sub-domain for all your projects, this allows you to
create a DNS record for the wildcard: `*.d.example.com`, which will
automatically direct all sub-sub-domain requests to your docker
server.

Note that you *could* put a wildcard record on your root domain, ie.
`*.example.com`, however if you did this you would not be able to use
the domain for a second instance, but if you're willing to dedicate
the entire domain to this single instance, go ahead.

If you don't want to create a wildcard record, you can just create
several normal `A` (or `AAAA`) records for each of the domains your
apps will use, but this might mean that you need to come back and add
several more records later as you install more projects, (and also
complicates the TLS certificate creation process) but this would let
you freely use whatever domain names you want.

### Notes on firewall

This system does not include a network firewall of its own. You are
expected to provide this in your host networking environment. (Note:
`ufw` is NOT recommended for use with Docker, nor is any other
firewall that is directly located on the same host machine as Docker.
You should prefer an external dedicated network firewall [ie. your
cloud provider, or VM host]. If you have no other option but to run
the firewall on the same machine, check out
[chaifeng/ufw-docker](https://github.com/chaifeng/ufw-docker#solving-ufw-and-docker-issues)
for a partial fix.)

With only a few exceptions, all network traffic flows through one of
several Traefik entrypoints, listed in the [static configuration
template](traefik/config/traefik.yml) (`traefik.yml`) in the
`entryPoints` section.

Each entrypoint has an associated environment variable to turn it on
or off. See the [Traefik](traefik) configuration for more details.

Depending on which services you actually install, you need to open
these (default) ports in your firewall:

   | Type   | Protocol | Port Range | Description                           |
   | ------ | -------- | ---------- | --------------------------------      |
   | SSH    | TCP      |         22 | Host SSH server (direct-map)          |
   | HTTP   | TCP      |         80 | Traefik HTTP endpoint                 |
   | TLS    | TCP      |        443 | Traefik HTTPS (TLS) endpoint          |
   | SSH    | TCP      |       2222 | Traefik Gitea SSH (TCP) endpoint      |
   | SSH    | TCP      |       2223 | SFTP container SSH (TCP) (direct-map) |
   | TLS    | TCP      |       5432 | PostgreSQL DBaaS (direct-map)         |
   | TLS    | TCP      |       8883 | Traefik MQTT (TLS) endpoint           |
   | WebRTC | UDP      |      10000 | Jitsi Meet video bridge (direct-map)  |
   | VPN    | TCP      |      51820 | Wireguard (TCP) (direct-map)          |

The ports that are listed as `(direct-map)` are not connected to
Traefik, but are directly exposed (public) to the docker host network.

For a minimal installation, you only need to open ports 22 and 443.
This would enable all of the web-based applications to work, except
for the ones that need an additional port, as listed above.

See [DIGITALOCEAN.md](DIGITALOCEAN.md) for an example of setting the
DigitalOcean firewall service.

Later, after you've deployed things, you can audit all of the open
published ports: from the root project directory, run `make
show-ports` to list all of the services with open ports (or those that
run in the host network and are therefore completely open. You will
find traefik and the wireguard server/client in this latter category).
Each sub-project directory also has a `make status` with useful
per-project information.

## Setup

### Install Docker CLI tools

You need to install the following tools on your local workstation:

 * [Install docker client](https://docs.docker.com/get-docker/) (For
   Linux, install Docker Engine, but not necessarily starting the
   daemon; the `docker` client program and `ssh` are all you need
   installed on your workstation to connect to a remote docker server.
   For Mac/Windows, install Docker Desktop, or use your own Linux
   Virtual Machine and install Docker Engine.)
 * [Install docker-compose
   v2.x](https://docs.docker.com/compose/cli-command/#installing-compose-v2)
   (For Docker Desktop, `docker compose` is already installed. For
   Linux, it is a separate installation.)
 * [Install docker
   buildx](https://docs.docker.com/build/buildx/install/) (optional,
   and *none* of the projects require it) - "Docker Buildx, is a CLI
   plugin that extends the docker command with the full support of the
   features provided by BuildKit builder toolkit." and it allows you
   to do cool things like [Heredocs in
   Dockerfiles](https://www.docker.com/blog/introduction-to-heredocs-in-dockerfiles/).

For Arch Linux, run: `sudo pacman -S docker docker-compose docker-buildx`

For Debian or Ubuntu, you should strictly follow the directions from
the links above and install only from the docker.com third party apt
repository (because the docker packages from the Ubuntu repositories
are always out of date).

You do not need to (and perhaps *should not*) run the Docker Engine on
your local workstation. You will use the `docker` client exclusively to
control a *remote* docker server (or VM). To turn off/disable the
Docker Engine on your worksation, run the following:

```
## Disable local Docker Engine:
sudo systemctl mask --now docker
```

#### Enable Docker buildx (optional)

Following the [buildx installation
guide](https://docs.docker.com/build/buildx/install/), and run the
installation:

```
docker buildx install
```

### Install workstation tools (optional)

There are also **optional** helper scripts and Makefiles included,
that will have some additional system package requirements (Note:
these Makefiles are just convenience wrappers for creating/modifying
your `.env` files and for running `docker compose`, so these are not
required to use if you would rather just edit your `.env` files by
hand and/or run `docker compose` manually.):

   * Base development tools including `bash`, `make`, `sed`, `xargs`, and
     `shred`.
   * `openssl` (for generating randomized passwords)
   * `htpasswd` (for encoding passwords for Traefik Basic Authentication)
   * `jq` (for processing JSON)
   * `xdg-open` (Used for automatically opening the service URLs in
      your web-browser via `make open`. Don't install this if your
      workstation is on a headless server, as it depends on
      Xorg/Wayland. Without installing `xdg-open`, it will degrade to
      simply printing the URL that you can copy and paste.)
   * `wireguard` (client for connecting to the [traefik
     wireguard](traefik#wireguard-vpn) VPN)

On Arch Linux, run this to install all these dependencies:

```
pacman -S bash base-devel openssl apache xdg-utils jq wireguard-tools
```

For Debian or Ubuntu, run:

```
apt-get install bash build-essential openssl apache2-utils xdg-utils jq wireguard
```

### Setup SSH access to the server

Make sure that your local workstation user account is setup for SSH
access to the remote docker server (ie. you should be able to ssh to
the remote server `root` account, or another account that has been
added into the `docker` group). You should setup key-based
authentication so that you don't need to enter passwords during login,
as each `docker` command will need to authenticate via SSH.

 * See the general article [How to Set Up SSH
   Keys](https://www.digitalocean.com/community/tutorials/how-to-set-up-ssh-keys-2)
 * Make sure to turn off regular password authentication, set
   `PasswordAuthentication no` in the server config.
 * Check out this [SSH Hardening
   Guide](https://www.sshaudit.com/hardening_guides.html) for
   disabling outdated key types.
 * If your workstation's operating system does not automatically provide an
   ssh-agent (to make it so you don't have to keep typing your key's
   passphrase), check out
   [Keychain](https://wiki.archlinux.org/title/Keychain#Keychain) for an easy
   solution.

When set for a remote Docker context, the `docker` command will create
a new SSH connection for each time it is run. This can be especially
slow for running several commands in a row. You can speed the
connection time up, by enabling SSH connection multiplexing, which
starts a single background connection and makes new connections re-use
this existing connection.

On your workstation, create or edit your existing
`${HOME}/.ssh/config` file. Add the following configuration (replacing
`ssh.d.example.com` with your own docker server hostname, and `root`
for the user account that controls Docker):

```
Host ssh.d.example.com
    User root
    IdentitiesOnly yes
    ControlMaster auto
    ControlPersist yes
    ControlPath /tmp/ssh-%u-%r@%h:%p
```

(The hostname `ssh.d.example.com` relies upon the wildcard
`*.d.example.com` or an explicit `A` record having been created for
this hostname.)

### Set remote Docker context

On your local workstation, create a new [Docker
context](https://docs.docker.com/engine/context/working-with-contexts/)
to use with your remote docker server (eg. named `d.example.com`) over
SSH:

```
docker context create d.example.com --docker "host=ssh://ssh.d.example.com"
docker context use d.example.com
```

(To benefit from connection multiplexing, make sure to use the exact
Host name [`ssh.d.exmaple.com`] that you specified in your
`${HOME}/.ssh/config`)

Now whenever you issue `docker` commands on your local workstation,
you will actually be controlling your remote Docker server through
SSH, and you can easily switch contexts between multiple server
backends.

For example, I have three docker contexts, for three different remote
Docker servers:

```
$ docker context ls
NAME              DESCRIPTION  DOCKER ENDPOINT
d.rymcg.tech *                 ssh://ssh.d.rymcg.tech
docker-vm                      ssh://docker-vm
pi                             ssh://pi
```

(The `*` indicates my current context.)

I can select to use which context I want to use:

```
$ docker context use docker-vm
Current context is now "docker-vm"
```

(This is a permanent setting that will survive a workstation reboot.
Use the same command again to switch to any other context.)

### Clone this repository to your workstation

```
git clone https://github.com/EnigmaCurry/d.rymcg.tech.git \
    ${HOME}/git/vendor/enigmacurry/d.rymcg.tech
cd ${HOME}/git/vendor/enigmacurry/d.rymcg.tech
```

## Main configuration

Run the configuration wizard, and answer the questions:

```
## Run this command inside the root source directory of d.rymcg.tech:
make config
```

(This writes the main project level variables into a file named
`.env_${DOCKER_CONTEXT}` (eg. `.env_d.example.com`) in the root source
directory, based upon the name of the current Docker context. This
file is excluded from the git repository via `.gitignore`.)

The `ROOT_DOMAIN` variable is saved in `.env_${DOCKER_CONTEXT}` and
will serve as the default root domain of all of the sub-project
domains, so that when you run `make config` in any of the sub-project
directories, the default (yet customizable) domain will be
pre-populated with this root domain suffix.

You can have multiple `.env_${DOCKER_CONTEXT}` files, one for each
Docker server, named after the associated Docker context. To switch
the current .env file being used, change the Docker context:

```
docker context use {CONTEXT}
```

## Install applications

Each of the sub-projects have their own `README.md`. You should
install [Traefik](traefik) first, as almost all of the others depend
on it. After that, install the [whoami](whoami) service to test that
things are working correctly.

Install these first:

* [Traefik](traefik) - HTTP / TLS / TCP / UDP reverse proxy
* [Whoami](whoami) - HTTP test service

Install these services at your leisure/preference:

* [ArchiveBox](archivebox) - a website archiving tool
* [Baikal](baikal) - a lightweight CalDAV+CardDAV server
* [Bitwarden](bitwarden_rs) - a password manager
* [CryptPad](cryptpad) - a collaborative document and spreadsheet editor 
* [DrawIO](drawio) - a diagram / whiteboard editor tool
* [Ejabberd](ejabberd) - an XMPP (Jabber) server
* [Filestash](filestash) - a web based file manager with customizable backend storage providers
* [FreshRSS](freshrss) - an RSS reader / proxy
* [Gitea](gitea) - Git host (like self-hosted GitHub) and oauth server
* [Invidious](invidious) - a Youtube proxy
* [Jitsi Meet](jitsi-meet) - a video conferencing and screencasting service
* [Jupyterlab](jupyterlab) - a web based code editing environment / reproducible research tool
* [Larynx](larynx) - a speech synthesis engine
* [Matterbridge](matterbridge) - a chat room bridge (IRC, Matrix, XMPP, etc)
* [Maubot](maubot) - a matrix Bot
* [Minio](minio) - an S3 storage server
* [Mosquitto](mosquitto) - an MQTT server
* [Nextcloud](nextcloud) - a collaborative file server
* [Node-RED](nodered) - a graphical event pipeline editor
* [Ntfy.sh](ntfy.sh) - a simple HTTP-based pub-sub notification service
* [Piwigo](piwigo) - a photo gallery and manager
* [PostgreSQL](postgresql) - a database server configured with mutual TLS authentication for public networks
* [PrivateBin](privatebin) - a minimal, encrypted, zero-knowledge, pastebin
* [Rdesktop](rdesktop) - a web based remote desktop (X11) in a container
* [S3-proxy](s3-proxy) - an HTTP directory index for S3 backend
* [SFTP](sftp) - a secure file server
* [Shaarli](shaarli) - a bookmark manager
* [Syncthing](syncthing) - a multi-device file synchronization tool
* [Thttpd](thttpd) - a tiny/turbo/throttling HTTP server for serving static files
* [TiddlyWiki (WebDAV version)](tiddlywiki-webdav) - A personal wiki stored in a single static HTML file
* [TiddlyWiki (NodeJS version)](tiddlywiki-nodejs) - Advanced server edition of TiddlyWiki with image CDN
* [Tiny Tiny RSS](ttrss) - an RSS reader / proxy
* [Traefik-forward-auth](traefik-forward-auth) - Traefik oauth middleware
* [Websocketd](websocketd) - a websocket / CGI server
* [XBrowserSync](xbs) - a bookmark manager

Bespoke things:

* [certificate-ca](_terminal/certificate-ca) Experimental ad-hoc certifcate CA. Creates
  self-signed certificates for situations where you don't want to use Let's
  Encrypt.
* [Linux Shell Containers](_terminal/linux) create bash aliases that
  automatically build and run programs in Docker containers.
* [_docker_vm](_docker_vm#readme) Run Docker in a Virtual Machine (KVM) on Linux.

## Command line interaction

As alluded to earlier, this project offers two ways to control Docker:

 1. Editing `.env` files by hand, and running `docker compose`
    commands yourself.
 2. Running `make` targets that edit the `.env` files automatically
    and runs `docker compose` for you (this is the author's preferred
    method).

Both of these methods are compatible, and they both get you to the
same place. The Makefiles offer a more streamlined approach with a
configuration wizard and sensible defaults. Most of the sub-project
README files reflect the `make` command style for config. Editing the
`.env` files by hand still offers you more control, with more freedom
for experimentation, and this option always remains available.

### Using `docker compose` by hand

For all of the containers that you wish to install, do the following:

 * Read the README.md file found in the sub-project directory.
 * Open your terminal and `cd` to the project directory containing
   `docker-compose.yaml`
 * Copy the example `.env-dist` to `.env`
 * Edit all of the variables in `.env` according to the example and comments.
 * Follow the README for instructons to start the containers.
   Generally, all you need to do is run: `docker compose up --build
   -d` (This is the same thing that `make install` does)

When using `docker compose` by hand, it uses the `.env` file name by default.
You can change this behaviour by specifying the `--env-file` argument.

### Using the Makefiles

Alternatively, each project has a `Makefile` that helps to simplify
configuration and startup. You can use the Makefiles to automatically
edit the `.env` files and to start the services for you.

The most important thing to know is that `make` looks for a `Makefile`
in your *current* working directory. `make` is contextual to the
directory you are in.

 * `cd` into the sub-project directory of an app you want to install.
 * Read the `README.md` file.
 * Run `make config`
 * Answer the interactive questions, and the
   `.env_${DOCKER_CONTEXT}_default` file will be created/updated for
   you (named with your current docker context, eg.
   `.env_d.example.com_default`). The answers are pre-populated with
   default values from `.env-dist` (and based upon your `ROOT_DOMAIN`
   specified earlier). You can accept the suggested default values, or
   use the backspace key and edit the value, to fill in your own
   answers. 
 * The suffix of the .env filename, `_default`, refers to the
   [instance](#creating-multiple-instances-of-a-service) of the
   service (each instance has a different name, with `_default` being
   the default name, and this is typical when you are only deploying a
   single instance.)
 * Verify the configuration by looking at the contents of
   `.env_${DOCKER_CONTEXT}_default`.
 * Run `make install` to start the services. (this is the same thing as
   `docker compose up --build -d`)
 * Most services have a website URL, which you can open automatically,
   run: `make open` (requires `xdg-utils`, otherwise it will print the
   URL and you can copy and paste it).
 * See `make help` (or just run `make`) for a list of all the other available
   targets, including `make status`, `make start`, `make stop` and `make
   destroy`. Be sure to recognize that `make` has tab completion in bash :)
 * You can also run `make status` in the root directory of the cloned
   source. This will list all of the installed/running applications.

`make config` *does not literally* create a file named `.env`, but
rather one based upon the current docker context:
`.env_${DOCKER_CONTEXT}_default`. This allows for different configurations to
coexist in the same directory. All of the makefile commands operate
assuming this contextual environment file name, not `.env`. To switch
between configs, you switch your current docker context: `docker
context use {CONTEXT}`.

During `make config`, you will sometimes be asked to create HTTP Basic
Authentication passwords, and these passwords can be *optionally*
saved into a file named `passwords.json` inside the sub-project
directory. This file is a convenience, so that you can remember the
passwords that you create. **`passwords.json` is stored in plain
text**, but excluded from being checked into git via `.gitignore`.
When you run `make open` the username and password stored in this file
is automatically applied to the URL that the browser is asked to open,
thus logging you into the website account automatically. To delete all
of the passwords.json files, you can run `make delete-passwords` in
the root directory of this project (or `make clean` which will delete
the `.env` files too).

For a more in depth guide on using the Makefiles, see
[MAKEFILE_OPS.md](MAKEFILE_OPS.md)

## Creating multiple instances of a service

By default, each project supports deploying a single instance per
Docker context. The singleton instance environment file is named
`.env_${DOCKER_CONTEXT}_default`, which is contained in each project
subdirectory (eg. `whoami/.env_d.example.com_default`).

If you want to deploy more than one instance of a given project (and
to the same docker context, and from the same source directory), you
need to create a separate environment file for each one. The
convention that the Makefile expects is to name your several
environment files like this: `.env_${DOCKER_CONTEXT}_${INSTANCE_NAME}`
(eg. `whoami/.env_d.example.com_foo`).

Not every project supports instances yet (nor does it make sense to in
some cases), it is opt-in for each project, by including the
[Makefile.instance](_scripts/Makefile.instance) file at the top of
their own Makefile.

By default, all of the `make` targets will use the default
environment, but you can tell it use the instance environment instead,
by setting the `instance` (or `INSTANCE`) variable:

```
make instance=foo config     # Configure a new or existing instance named foo
make instance=bar config     # (Re)configures bar instance
make instance=foo install    # This (re)installs only the foo instance
make instance=bar install    # (Re)installs only bar instance
make instance=foo ps         # This shows the containers status of the foo instance
make instance=foo stop       # This stops the foo instance
make instance=bar destroy    # This destroys only the bar instance

# Show the status of all instances of the current project subdirectory:
make status
```

It may seem tedious to repeat typing `instance=foo` everytime (and its
easy to forget!), so there is a shortcut: `make instance`, which will
ask you to enter an instance name, and then enter a new sub-shell with
the environment variables set for that instance, making it now the
default within the sub-shell, so you don't have to type it anymore:

```
# Use this to create a new instance (or to use an existing one):
# Enter a subshell with the instance temporarily set as the default:
make instance
```

Example:

```
## Example terminal session for creating a new instance of whoami named foo:

$ cd ~/git/vendor/enigmacurry/d.rymcg.tech/whoami
$ make instance
Enter an instance name to create/edit
: foo
Configuring environment file: .env_d.rymcg.tech_foo
WHOAMI_TRAEFIK_HOST: Enter the whoami domain name (eg. whoami.example.com)
: whoami-foo.d.rymcg.tech
WHOAMI_NAME: Enter a unique name to display in all responses
: foo
Set WHOAMI_INSTANCE=foo
## Entering sub-shell for instance foo.
## Press Ctrl-D to exit or type `exit`.

(context=d.rymcg.tech project=whoami instance=foo)
whoami $
```

Inside the sub-shell, the `PS1` BASH prompt has been set so that it
will remind you of your current locked instance:
`(context=d.rymcg.tech project=whoami instance=foo)`. You have access
to all of the same `make` targets as before, but now they will apply
to the instance by default:

```
## Inside of the foo instance sub-shell ...
make config                  # (Re)configures foo instance
make install                 # (Re)installs foo instance
make destroy                 # Destroys foo instance
etc...
```

To exit the sub-shell, press `Ctrl-D` or type `exit` and you will
return to the original parent shell and working directory.

If you want to enter the sub-shell without automatically running `make
config`, you can run `make switch` rather than `make instance`.

### Overriding docker-compose.yaml per-instance

Most of the time, when you create multiple instances, the only thing
that needs to change is the environment file
(`.env_${DOCKER_CONTEXT}_${INSTANCE}`). Normally the
`docker-compose.yaml` is static and stays the same between several
instances.

However, sometimes you need to configure the `docker-compose.yaml` of
two instances a little bit differently from each other, but mostly
stay the same. You may also wish to modify the configuration without
wanting to commit those changes back to the base template in the git
repository.

You can override each project's `docker-compose.yaml` with a
per-docker-context `docker-compose.override_${DOCKER_CONTEXT}_default.yaml`
(default instance) or a per-instance
`docker-compose.override_${DOCKER_CONTEXT}_${INSTANCE}.yaml` file.

You can find an example of this in the [sftp](sftp) project. Each
instance of sftp will need a custom set of volumes, and since this is
normally a static list in `docker-compose.yaml`, you need a way of
dynamically generating it. There is a template
[docker-compose.instance.yaml](sftp/docker-compose.instance.yaml) that
when you run `make config` it will render the template to the file
`docker-compose.override_${DOCKER_CONTEXT}_default.yaml` containing
the custom mountpoints (this file is ignored by git.) The override
file is merged with the base `docker-compose.yaml` whenever you run
`make install`, thus each instance receives its own list of volumes to
mount.

Reference the Docker compose documentation for [Adding and overriding
configuration](https://docs.docker.com/compose/extends/#adding-and-overriding-configuration)
regarding the rules for how the merging of configuration files takes
place.

## Backup .env files (optional)

Because the `.env` files contain secrets, they are to be excluded from
being committed to the git repository via `.gitignore`. However, you
may still wish to retain your configurations by making a backup. This
section will describe how to make a backup of all of your `.env` and
`passwords.json` files into a GPG encrypted tarball, and how to
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

The script will ask to add `GPG_RECIPIENT` to your
`.env_${DOCKER_CONTEXT}_default` file. Enter the GPG pub key ID value
for your key.

A new encrypted backup file will be created in the same directory
called something like
`./${DOCKER_CONTEXT}_environment-backup-2022-02-08--18-51-39.tgz.gpg`.
The `GPG_RECIPIENT` key is the *only* key that will be able to read
this encrypted backup file.

### Clean environment files

Now that you have an encrypted backup, you may wish to delete all of
the unencryped `.env` files. Note that you will not be able to control
your docker-compose projects without the decrypted .env files, but you
may restore them from the backup at any time.

To delete all the .env files, you could run:

```
## Make sure you have a backup of your .env files first:
make clean
```

### Restore .env files from backup

To restore from this backup, you will need your GPG private keys setup
on your worstation, and then run:

```
make restore-env
```

Enter the name of the backup file, and all of the `.env` and
`passwords.json` files will be restored to their original locations.

## Integrating external projects

You can integrate your own docker-compose projects that exist in
external git repositories, and have them use the d.rymcg.tech
framework:

 * Clone d.rymcg.tech and set it up (Install Traefik, and whoami, make
   sure that works first).
 * Create a new project directory, or clone your existing project, to
   any other directory. (It does not need to be a sub-directory of
   `d.rymcg.tech`, but it can be).
 * In your own project repository directory, create the files for
   `docker-compose.yaml`, `.env-dist`, and `Makefile`. As an example,
   you can use any of the d.rymcg.tech sub-projects, like
   [whoami](whoami).

Create the `Makefile` in your own separate repository so that it
includes the main d.rymcg.tech `Makefile.projects` file from
elsewhere:

```
## Example Makefile in your own project repository:

# ROOT_DIR can be a relative or absolute path to the d.rymcg.tech directory:
ROOT_DIR = ${HOME}/git/vendor/enigmacurry/d.rymcg.tech
include ${ROOT_DIR}/_scripts/Makefile.projects

.PHONY: config-hook # Configure .env file
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} EXAMPLE_TRAEFIK_HOST "Enter the example domain name" example.${ROOT_DOMAIN}
	@${BIN}/reconfigure_ask ${ENV_FILE} EXAMPLE_OTHER_VAR "Enter the example other variable"
```

A minimal `Makefile`, like the one above, should include a
`config-hook` target that reconfigures your `.env` file based upon the
example variables given in `.env-dist`.

Now in your own project directory, you can use all the regular `make`
commands that d.rymcg.tech provides:

```
make config
make install
make open
# etc
```
