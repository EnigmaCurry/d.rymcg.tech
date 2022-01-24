# Linux shell containers

This project will help create and manage several temporary yet long-running
shell accounts inside containers. Each container is joined to the same docker
network and has a common volume for easily sharing files between containers
(mounted at `/shared`)

You can kind of treat these as disposable Virtual Machines.. kind of. This is
intended for interactive terminal programs, not for network service daemons, but
you can start `screen` or `tmux` sessions to supervise any long running process,
and they will run until the container is stopped. (Sorry, systemd does not work!
It does actually, but it requires the `SYS_ADMIN` capability to do it, and so
I've chosen to leave systemd disabled for security purposes.) You can stop and
restart these containers, and they will retain all of their data (and installed
packages) between restarts. If you remove the containers (`make destroy` or
`docker rm ...`) then all data will be lost. A container that is in a stopped state
is vulnerable to container pruning (ie. you may wish to reclaim storage space on
your Docker server with `docker container prune`, but this will delete all
stopped containers and all of their data.)

## Setup

This `Makefile` works equally well with Docker as with Podman. It will default
to use the `docker` command, but you can set the environment to use `podman`
instead:

```
## If you want to use podman instead of docker:
export DOCKER=podman
```

## Quickstart

Run `make` to see the main help screen, listing all of the targets.

```
$ make
make network        - Make the docker network (named ${NETWORK})
make list           - List all shell containers
make start          - Start the shell container (named ${NAME})
make stop           - Stop the shell container (named ${NAME})
make stop-all       - Stop all the shell containers
make shell          - Connect to the shell container (named ${NAME})
make destroy        - Destroy the shell container (named ${NAME})
make prune          - Prune all the stopped shell containers
make destroy-all    - Destroy all the shell containers
make alpine         - Create the Alpine singleton
make arch           - Create the Arch singleton
make busybox        - Create the Busybox singleton
make python         - Create the Python singleton
make debian         - Create the Debian singleton
make fedora         - Create the Fedora singleton
make ubuntu         - Create the Ubuntu singleton
```

Create the docker network that will be shared between containers:

```
## Create the default 'shell-lan' network:
make network
```

Start the default shell container:

```
# Start the shell with the default ${NAME} (arch)
make shell
```

The default `NAME` variable is `arch`, so you should be thrown into a new
subshell with that hostname:

```
[root@arch /]# 
```

You can do all things you can with Arch Linux here (but there's no systemd).
When you're done, press `Ctrl-D` or type `exit`. However, the container is still
running in the background, and you can re-attach again later, just run `make
shell` again.

Back in your host shell, you can start a new shell container with a different
name:

```
NAME=two make shell
```

Again, you'll be put into a new sub-shell, but this time with the hostname
`two`:

```
[root@two /]# 
```

Press `Ctrl-D` or type `exit` to leave this shell. The container will be left
running in the background.

Now you have two instances running: one named `arch` and one name `two`.

You can list all the instances:

```
make list
```

You can stop both instances:

```
NAME=arch make stop
NAME=two make stop
```

You can restart instances:

```
NAME=arch make start
```

You can re-attach to shells (even if stopped):

```
NAME=two make shell
```

## Environment variables

As you can see from the `Quickstart` this Makefile is modified by environment
variables. Here is a list of the variables you can set (with their defaults
listed in parentheses):

 * `DOCKER` (`docker`) you can set this to `podman` and your containers will run
   in Podman rather than Docker.
 * `IMAGE` (`archlinux`) you can set this to any container image (eg.
   `alpine:3.15`, `debian:11-slim`, `ubuntu`, etc.)
 * `NAME` (`arch`) the container name and hostname can be set using this.
 * `NETWORK` (`shell-lan`) the name of the network to attach to.
 * `SHARED_VOLUME` (`shell-shared`) the name of the volume to share between containers.
 * `SHARED_MOUNT` (`/shared`) the mount point for the shared volume.

## Examples

### Arch Linux

```
export IMAGE=docker.io/archlinux 
export NAME=my_arch 
make shell
```

or

```
## Create the archlinux singleton named 'arch'
make arch
```


### Alpine Linux

```
export IMAGE=docker.io/alpine
export NAME=my_alpine
make shell
```

or

```
## Create the Alpine singleton named 'alpine'
make alpine
```

### Debian

```
export IMAGE=docker.io/debian:11-slim
export NAME=my_debian
make shell
```

or

```
## Create the Debian singleton named 'debian'
make debian
```


### Ubuntu

```
export IMAGE=docker.io/ubuntu:21.04
export NAME=my_ubuntu
make shell
```

or

```
## Create the Ubuntu singleton named 'ubuntu'
make ubuntu
```


### Busybox

```
export IMAGE=docker.io/busybox
export NAME=my_busybox
make shell
```

or

```
## Create the Busybox singleton named 'busybox'
make busybox
```

### Fedora

```
export IMAGE=docker.io/fedora
export NAME=my_fedora
make shell
```

or

```
## Create the Fedora singleton named 'fedora'
make fedora
```


### Python

```
export IMAGE=docker.io/python:3
export NAME=my_python
make shell
```

or

```
## Create the Python singleton named 'python'
make python
```
