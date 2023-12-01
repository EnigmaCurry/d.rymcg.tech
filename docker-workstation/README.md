# Docker Workstation Container

This is an Arch Linux based development container for
[d.rymcg.tech](d.rymcg.tech). Install this on a secure Docker server,
and you can use this as your remote Docker workstation that you
connect to through SSH. All of your d.rymcg.tech `.env` files and
tools will live inside this container (in a volume). Once installed,
you can setup access for all of your remote Docker server contexts,
each to be exclusively controlled through this single container
workstation.

![Your laptop/workstation, the Docker Container Worksation, and the
production Docker host](container_workstation.png)

Once you've configured this container to be the sole docker client for
your digital empire, locking down access becomes trivial: simply turn
off this container, and nothing will remain on your normal
laptop/workstation. Only turn it back on if you need to install new
containers, or do some kind of maintainance; turn it back off when
you're done, and this becomes a powerful form of access control.

You will build a Docker image that includes all of the dependencies
that you need to run an SSH service, a Docker client, the d.rymcg.tech
tools, and a full Emacs and web browser develoment environment. You
will be able to connect to the container via SSH, and with X11
forwarding enabled, be able to run its graphical applications (eg.
Emacs and Firefox) remotely from your local client computer. Although
Emacs can also be used from a terminal user interface (`emacs -nw`),
having a fully graphical Firefox, living inside the container, is
helpful to do maintainance tasks like viewing the Traefik dashboard
(which is not normally accessible, except through local SSH forward.
With X11 forwarding, this allows you to view the dashboard from a
third device: your client laptop). Because the browser runs over X11
forwarding, you can safely use the bookmarks and password manager
builtin to Firefox, where its database is stored securely inside the
container (and not in your local home directory).

## Definitions

A workstation is a personal computer, one that you are directly logged
into and interacting with. A worksation is usually a physical computer
that you touch, like a laptop. However, a workstation can also be a
remote computer. The distinction between a workstation and a server,
is not about hardware, but rather the role that the machine is
deployed as. In the context of Docker, a workstation is what uses the
`docker` command line *client*. A Docker host is the *server* that
runs the docker daemon, and all your containers.

So the Docker Workstation Container, is a workstation, that runs as a
docker container, that is setup as a *client* to control *other*
Docker hosts, via SSH.

## Where should I install this container?

It is recommended to install the workstation container on a secure
Docker server (or VM) that is *separate* from your production Docker
servers (and be able to be shutdown, separately, when it's not
needed). Although access to this container is protected by an SSH key
(and SSH passwords have been disabled), you may still want to segment
access by network, having it be not accessible publicly from the
internet, by running this on a private LAN, or from inside of a VPN,
or from behind another jump host.

If you have limited compute resources, and as an alternative to a
remote Docker server, you could setup a secure VM on your normal
laptop/workstation, using the
[_docker_vm](https://github.com/EnigmaCurry/d.rymcg.tech/tree/master/_docker_vm#localhost-docker-on-kvm-virtual-machine),
making sure to install the VM in a *separate dedicated user account*
from the one you normally use. You can then start/stop the VM using
`sudo` to control the secondary user account. As long as your `sudo`
access is secured properly, you can securely run a "remote"
workstation container on the same physical machine, isolated in two
separate userspaces. (The important point here is that the VM disk
files should be owned by a separate user from your normal one, and so
they cannot be read by rogue processes in your main account. You want
to ensure that the only way your normal account can access it, is
through SSH, and only when its turned on.)

## Two ways to install

There are two ways to install this:

 1) From an existing local install of d.rymcg.tech, setup only to
 control the Docker host that will run the worksation container (but
 *not* setup to access the production Docker server!)
 
 2) Directly on the docker host, which has zero dependencies other
 than docker.

### Install with d.rymcg.tech

#### Config (make config)

```
make config
```

Enter the information asked:

 * `DOCKER_WORKSTATION_HOSTNAME` - the hostname for the new container
 * `DOCKER_WORKSTATION_USERNAME` - the username for the new user account inside the container
 * `DOCKER_WORKSTATION_AUTHORIZED_KEY` - the SSH public key for authorized access

You should already have an SSH key on your normal laptop/workstation.
If not, run `ssh-keygen`. Copy the public key (eg. from
`~/.ssh/id_rsa.pub`) and set it as `DOCKER_WORKSTATION_AUTHORIZED_KEY`. (The
key should be one long line like `ssh-rsa AAAAA...` or
`ecdsa-sha2-nistp256 AAAA...`)

Configuration for multiple SSH keys is not provided at this time.

#### Build (make build)

This is a *fat* container, which contains dozens of preinstalled Arch
Linux packages, comprising a full Docker and Emacs development
environment, as well as the Firefox web browser. It could take up to
10 or 20 minutes to build everything. This is Arch Linux, so you are
recommended to build this image yourself, thereby downloading the
latest packages. (This is why this container is not provided as an
image you can pull from a registry, but a variation on this could be
made upon a non-rolling release like Debian, and published as a
semi-static image. But for Arch Linux, I think this would be an
anti-pattern; you should build it yourself, fresh, but you could then
publish your custom image to make it easier for yourself to re-use).

```
## Build the image - be patient!
make build
```

#### Install (make install)

Once you have built the image, you can install it:

```
make install
```

#### Connect to it via SSH (make shell)

You can connect to the container through SSH. Using the `make shell`
command does not require any further configuration:

```
make shell
```

This will connect you to the container via SSH (on port 2222 by
default) and run the default shell.

#### Connect to the root shell (make root-shell)

If for some reason SSH does not connect you, you can debug the service
with the root shell. To connect to the root shell, run:

```
make root-shell
```

### Install with Docker (no dependencies)

If you are creating a Docker host for the sole purpose of running this
container, you may not feel it necessary to install d.rymcg.tech, just
for this one container. Alternatively, you can build and install the
container directly on the Docker host:

```
# Build the image directly on the Docker host:
docker build -t docker-workstation \
  https://github.com/EnigmaCurry/d.rymcg.tech.git#:docker-workstation/arch
```

(You may add any of the [build
arguments](https://docs.docker.com/build/guide/build-args/) to the
build command to change the default values: `ARCH_MIRROR`, `USERNAME`,
`BASE_PACKAGES`, `EXTRA_PACKAGES`, `EMACS_CONFIG_REPO`,
`EMACS_CONFIG_BRANCH`. For example, add `--build-arg=USERNAME=ryan` to
change the default username)

Now that you have built an image called `docker-workstation`, you can
start the container. Make sure the `HOST`, `AUTHORIZED_KEY` and
`SSH_PORT` variables are set at *runtime*:

```
## Set the hostname (also used as the container name):
HOST=workstation
## Set the external ssh port:
SSH_PORT=2222
## Set your actual SSH public key here:
AUTHORIZED_KEY="ssh-rsa AAAA......"
```

```
docker run -d \
  --name "${HOST}" \
  --hostname "${HOST}" \
  -e AUTHORIZED_KEY="${AUTHORIZED_KEY}" \
  -p "${SSH_PORT}:22" \
  docker-workstation
```

## Configure SSH client (on your native laptop/workstation)

To make connecting easy, you should create an SSH config entry in your
`~/.ssh/config` file:

```
# Put this in ~/.ssh/config:
# Name the Host whatever you want:
Host docker-workstation
    # Enter the real IP address or the DNS name of the Docker host:
    Hostname x.x.x.x
    # Enter the external SSH port forwarding to the container port 22:
    Port 2222
    # Enter the username configured for the workstation container:
    User user
    # Enable X11 forwarding:
    ForwardX11 yes
    # Enable SSH connection sharing:
    ControlMaster auto
    ControlPersist yes
    ControlPath /tmp/ssh-%u-%r@%h:%p
```

With the new config in place, you can connect directly via ssh:

```
ssh docker-workstation
```

## Emacs

This container includes my own custom [Emacs
enviornment](https://github.com/enigmacurry/emacs#readme), which you
can configure to use your own config (and git repository), or if you
don't want to use Emacs, you can disable it entirely in the config.

Emacs can be run as a daemon, and that way allow you to restore your
session if you ever get disconnected.

First, start the Emacs daemon:

```
make emacs-daemon

## Or:
## ssh docker-workstation emacs --daemon
```

The first time this runs, it will build the Emacs packages, and then
start the daemon in the background.

You can connect to your session once it has started:

```
make emacsclient

## Or:
## ssh docker-workstation emacsclient -c
```

You are allowed to disconnect and reattach; the session will persist
for as long as the Emacs daemon is running.

## Custom Packages

If you don't want to use Emacs, you can install whatever editors you
want, from the Arch Linux repositories. You can also install whatever
other packages you want, fully customizing your own image.

There are three important config variables related to packages:

 * `DOCKER_WORKSTATION_ARCH_MIRROR` this is the Arch Linux package
   repository (mirror) - you should customize this for a fast local
   mirror for your location, choose from the [the global mirror
   list](https://archlinux.org/mirrorlist/all/).
 * `DOCKER_WORKSTATION_BASE_PACKAGES` this is a list of all the
   packages that should be installed in the base layer of the image.
 * `DOCKER_WORKSTATION_EXTRA_PACKAGES` this is a list of all the
   additional packages that should be installed at the end of the
   image. When you want to test a new package, add them to the extra
   list, and rebuild the image (the build will be faster than adding
   it the the base list). You can consider moving these packages into
   `DOCKER_WORKSTATION_BASE_PACKAGES` later after you are done testing
   them, and you want to bake them into the image permanently (giving
   the build more efficient storage).

## Persistence

Containers don't persist files unless they are stored in a volume.
This container only has two volumes, mounted to:

 * `/etc/ssh/keys`
 * `/home/${DOCKER_WORKSTATION_USERNAME}`

Files stored in any of these locations are persistent, even if you
rebuild or upgrade the container. Any files, including packages you
install, that are not stored here are lost when you rebuild or upgrade
the container.

All permanent customization must be done in the Dockerfile, or via one
of the customizable environment variables: (eg.
`DOCKER_WORKSTATION_BASE_PACKAGES` and/or
`DOCKER_WORKSTATION_EXTRA_PACKAGES`).
