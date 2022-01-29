# Linux shell containers

This project will help create and manage several temporary yet long-running
shell accounts inside containers. Each container is joined automatically to the
same docker network and have a common volume for easily sharing files between
containers (mounted at `/shared`)

You can kind of treat these as disposable Virtual Machines.. kind of. This is
intended for interactive terminal programs, not for network service daemons, but
you can start `screen` or `tmux` sessions (or `systemd`) to supervise any long
running processes, and they will run until the container is stopped. You can
stop and restart these containers, and they will retain all of their data (and
installed packages) between restarts. If you remove the containers then all data
will be lost. A container that is in a stopped state is also vulnerable to
container pruning (ie. you may wish to reclaim storage space on your Docker
server with `docker container prune`, but this will delete all stopped
containers and all of their data.)

This script will work with Docker and/or Podman. Docker has an *optional*
dependency on [sysbox](https://github.com/nestybox/sysbox) which you may install
in order to run unprivileged systemd inside a container as PID 1. (Sysbox is not
required for Podman which supports systemd natively.)

## Config

Make sure you have cloned this repository somewhere on your workstation:

```
git clone https://github.com/EnigmaCurry/d.rymcg.tech.git \
   ~/git/vendor/enigmacurry/d.rymcg.tech
```

Install the `shell_container` function in your Bash shell, put the following in
your `${HOME}/.bashrc` file:

```
## Linux Shell Containers:
## imports the shell_container function:
source ${HOME}/git/vendor/enigmacurry/d.rymcg.tech/_terminal/linux/shell.sh
```

Open a new shell, and you will have access to the `shell_container` function,
with which you can create new aliases for your containers:

```
alias arch='shell_container template=arch'
alias debian='shell_container template=debian'
alias fedora='shell_container template=fedora'
```

Try creating different aliases in your shell, and play around. Then once you've
settled on an alias that works well for you, put in your `${HOME}/.bashrc` file
to keep it permanently.

The names of the aliases do not matter, only the template name that you pass
does. The template names are the same as the Dockerfile extension names found in
the [images](images) directory (or this can be overriden with the `dockerfile`
and `builddir` arguments).

You may also add additional arguments to the aliases to modify the container or
how it runs, for example:

```
## podman_arch will run the arch template in Podman, instead of Docker:
alias podman_arch='shell_container template=arch docker=podman'
## user_arch will run the arch template always with the username 'user':
alias user_arch='shell_container template=arch username=user'
```

Also be aware that you can pass additional arguments when you invoke the alias:

```
podman_arch shared_volume=my_volume shared_mount=/mnt/demo systemd=true --start
```

## Config arguments

Config arguments may be passed as `name=value` arguments to the
`shell_container` function and your aliases:

 * `template` - The name of the Dockerfile template (eg. arch, debian, etc.)
 * `name` - The hostname of the container (default: the same as the template name)
 * `username` - The shell username inside the container (default: root)
 * `user` - Alias for `username` (when using environment vars always use `USERNAME`)
 * `entrypoint` - The shell command to start (default: `/bin/bash`, and fallback
   `/bin/sh` )
 * `sudo` - If sudo=true give sudo privileges to the shell user (default: false)
 * `network` - The name of the container network to join (default: shell-lan)
 * `workdir` - The path of the working directory for the shell (default: /)
 * `docker` - The name/path of the docker or podman executable (default: docker)
 * `systemd` - If systemd=true, start systemd as PID1 (default: false)
 * `sysbox` - If sysbox=true, run the container with the sysbox runtime (default: false)
 * `shared_volume` - The name of the volume to share with the container (default: shell-shared)
 * `shared_mount` - The mountpoint inside the container for the shared volume: (default: /shared)
 * `dockerfile` - Override the path to the Dockerfile (default: images/Dockerfile.$TEMPLATE)
 * `builddir` - Override the build context directory (default: directory containing shell.sh)
 * `docker_args` - Adds additional docker run arguments (default: none)

Alternatively, the config may be passed as environment variables. (Use
uppercased names for environment variables, eg. `TEMPLATE`, `NAME`, etc.)

## Sub-commands

You may pass various commands to your `shell_container` aliases with arguments
that start with `--`:

 * `--help` - Shows this help screen
 * `--build` - Build the template container image
 * `--list` - List all the instances of this template
 * `--start` - Start this instance without attaching
 * `--start-all` - Start all the instances of this template
 * `--stop` - Stop this instance
 * `--stop-all` - Stop all the instances of this template
 * `--prune` - Remove all stopped instances of this template
 * `--rm ` - Remove this instance
 * `--rm-all` - Remove all instances of this template

Note: sub-commands must come *after* all of the [Config arguments](#config-arguments)

## More examples

Please see the full help screen from any of your aliases with the `--help`
argument (eg. `arch --help`, or on the main function: `shell_container --help`)

Here's some more example aliases:

```
## Podman systemd enabled Arch Linux:
alias podman_arch='shell_container template=arch docker=podman systemd=true'

## Docker systemd enabled Arch Linux (requires sysbox-runc to be installed):
alias docker_arch='shell_container template=arch docker=podman systemd=true sysbox=true'

## Podman debian:
alias debian='shell_container template=debian docker=podman
```

You must build the container image the first time:
```
podman_arch --build
```

Create three instances without attaching them:

```
podman_arch one --start
podman_arch two --start
podman_arch three --start
```

Connect to the first one as the user `ryan`:

```
podman_arch sudo=true ryan@one
```

(the user `ryan` will automatically be created and given sudo privleges because
`sudo=true`)


(You'll enter the shell in the `one` container now, press `Ctrl-D` or type
`exit` when done, the container will still be running in the background.)

List all the instances of the template `arch`:

```
podman_arch --list
```

(Note that if you invoked `arch --list`, it would show the same instances [as
long as its the same docker], because they are both from the same template:
`arch`. If you want these to be distinct templates, you can symlink
`Dockerfile.arch` to `Dockerfile.podman_arch`)

Remove all the containers running the template `arch` :

```
arch --rm-all
```

## Vendored Dockerfile example

Suppose you have discovered a new project that includes a `Dockerfile` to build
that project as an image. You can use this directly with `shell_container`!

Take this example: [enigmacurry/daw](https://github.com/EnigmaCurry/daw/). This
repository has a `Dockerfile` in the root directory, and so can be used with
`shell_container`. 

`enigmacurry/daw` is a Python powered Digital Audio Workstation (not really, its
just some python code that makes some sound at this point). This container sends
audio to your host pulseaudio server (only tested on Arch Linux).

Clone the repository:

```
git clone https://github.com/EnigmaCurry/daw.git ~/git/vendor/enigmacurry/daw
```

Create a new alias that points to the project Dockerfile:

```
alias daw='shell_container docker=podman template=daw builddir=${HOME}/git/vendor/enigmacurry/daw dockerfile=${HOME}/git/vendor/enigmacurry/daw/Dockerfile docker_args="--volume=/run/user/$(id -u)/pulse:/run/user/1000/pulse" shared_volume=${HOME}/git/vendor/enigmacurry/daw shared_mount=/app workdir=/app/projects'
```

The arguments explained:

 * `docker=podman` - This uses Podman instead of Docker to create the container
 * `template=daw` - The name of the template. The name of the Dockerfile used to
   build the image is normally derrived from this template name, however because
   `dockerfile` is specified too, this can be any name you want.
 * `dockerfile` - This overrides the Dockerfile used to build the image.
 * `builddir` - This overrides the build context directory to use the project root.
 * `docker_args` - These are any extra `docker run` arguments, in this case to
   mount the pulseaudio socket.
 * `shared_volume` - This uses a host directory as the shared volume
 * `shared_mount` - This mounts the shared volume at `/app` inside the container
 * `workdir` - This starts the shell from the directory `/app/projects`

Build the container image:

```
daw --build
```

Run the shell:

```
daw
```

You can test if audio is working (warning: will play loud static noise):

```
pacat -vvvv /dev/urandom
```

(Press `Ctrl-C` to stop and `Ctrl-D` to quit the container)

Stop the container:

```
daw --stop
```

Remove the container (stops if needed):

```
daw --rm
```
