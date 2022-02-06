# Linux shell containers

This tool will create and manage several temporary, ephemeral containers,
hosting short and/or long-running shell accounts. Each container is joined
automatically to the same docker/podman network and have a common mounted volume
for easily sharing files between containers (eg. `/shared`). With customizable
Bash shell aliases, and on-the-fly container creation, Linux Shell Containers
provides an ergonomic method of creating quick virtual environments.

```
# After installation and defining a custom bash alias, you'll be able to ....
# Instantly create, start, and exec into a clean Arch Linux container:
arch

# or Debian ... or ...anything else you setup a shell_container alias for:
debian
```

This puts you directly into the shell of the container (starting it if
necessary). If you exit the shell, the container stays running in the
background. This lets you run long running processes like `screen`, `tmux`, (or
even `systemd` with some caveats), and you can log back in later the same way.

``` 
# Turn off the container:
arch --stop
# Turn it back on:
arch --start
# Remove it, and all of the data not explicity stored in a volume:
arch --rm

# Start a new container named 'light', and create the user 'sparrow':
# (--start will start the container in the background)
arch sparrow@light --start

# Start two more:
arch sparrow@dark --start
arch hector@smc --start

# List all three of them:
arch --list

# Remove (destroy) all three of them:
arch --rm-all
```

Systemd is optional, and turned off by default. By default, containers run a
terminal program, and stop when the program quits. For persistent containers,
(`persistent=true`) the default "init" is just a simple `while true; do sleep
10; done` loop, in order to keep the container alive in the background. This way
you can run `screen` or `tmux`, and disconnect and reconnect later. While not a
true init, it seems to do the job.

This script will work with Docker and/or Podman. Docker has an *optional*
dependency on [sysbox](https://github.com/nestybox/sysbox) which you may install
only if you want to run unprivileged systemd inside a container as PID 1.
(Sysbox is not required for Podman which supports systemd natively.)

Remember, these are containers, not Virtual Machines, they are designed to be
destroyed. You can install/remove packages interactively, and create/edit any
files in the filesystem, stop and restart them, treat them like pets, but the
data they hold will only persist for the lifecycle of the container, unless
files are explicitly saved in a mounted volume (eg. `/daw` or `/shared`). Once
you run the arguments `--rm` or especially `--prune`, the data is gone forever.

If you rebuild/upgrade the container image, all the existing containers (even
the stopped ones) will stay on the old image version. You must recreate (`--rm`
and then `--start`) containers in order to use the updated image.

## Setup and Config

Make sure you have cloned this repository somewhere on your workstation:

```
git clone https://github.com/EnigmaCurry/d.rymcg.tech.git \
   ~/git/vendor/enigmacurry/d.rymcg.tech
```

Install the `shell_container` function in your Bash shell, by putting the
following in your `${HOME}/.bashrc` file:

```
## Linux Shell Containers:
## imports the shell_container function:
source ${HOME}/git/vendor/enigmacurry/d.rymcg.tech/_terminal/linux/shell.sh
```

Open a new shell, and you will have access to the `shell_container` function,
with which you can create new aliases for your containers:

```
alias arch='shell_container template=arch'
alias debian='shell_container template=debian sudo=true'
alias fedora='shell_container template=fedora docker=podman systemd=true'
```

Try creating different aliases in your shell, and play around. Then once you've
settled on an alias that works well for you, put it in your `${HOME}/.bashrc`
file to keep it available permanently.

The names of the aliases do not matter (and cannot be detected by the script),
only the template name and other arguments that you pass matter. The template
names indicate the the default build directory to use from the [images](images)
directory (or this can be overriden with the `buildsrc` and `dockerfile`
arguments). The template name also serves as a label on containers to group
select them by template name for the operations `--list`, `--start-all`, `--stop-all`, and
`--rm-all`.

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
 * `buildsrc` - Override the build context directory (default: directory containing shell.sh)
 * `docker_args` - Adds additional docker run arguments (default: none)
 * `build_args` - Adds additional build arguments: (default: --build-arg FROM)
 * `persistent` :: If persistent=true, keep the container running (default:
   false)

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
alias podman_arch='shell_container template=arch persistent=true docker=podman systemd=true'

## Docker systemd enabled Arch Linux (requires sysbox-runc to be installed):
alias docker_arch='shell_container template=arch persistent=true docker=podman systemd=true sysbox=true'

## Podman debian:
alias debian='shell_container template=debian persistent=true docker=podman

## Arch Linux on Raspberry Pi (arm64) which requires a different base image:
alias arch='shell_container template=arch persistent=true from=faddat/archlinux'

## tty-clock displays a digital clock in your terminal.
## This builds directly from a git repository on github:
alias clock='TIMEZONE=America/Los_Angeles shell_container docker=podman template=tty-clock build_args="--build-arg TIMEZONE" buildsrc=https://github.com/enigmacurry/tty-clock.git command="tty-clock -c -s -C 3 -b"'
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


(You'll enter the shell in the `one` container now. Press `Ctrl-D` or type
`exit` when done, and the container will still be running in the background.)

List all the instances of the template `arch`:

```
podman_arch --list
```

(Note that if you invoked `arch --list`, it would show the same instances as
`podman_arch --list` [true only if both aliases use docker=podman], because they
are both from the same template: `arch`. If you want these two groups to be
separate, you need to use distinct template names.)

Remove all the containers running the template `arch` :

```
podman_arch --rm-all
```

## Vendored Dockerfile example

Suppose you have discovered a random new project that includes a `Dockerfile` to
build that project as an image. You can build and use this directly with
`shell_container`! You can use this method to replace those cumbersome,
programming language specific, virtual packaging environments, like Python
`virtualenv`. Use this same method for all your projects, no matter the language
they are written in, they just need a `Dockerfile`.

Take this example: [enigmacurry/daw](https://github.com/EnigmaCurry/daw/). This
repository includes a `Dockerfile`, and so it can be used with
`shell_container`.

`enigmacurry/daw` is a Python powered Digital Audio Workstation (well not
really, its just some python code that makes some sound at this point). This
container sends audio to your host pulseaudio server (only tested on Arch
Linux).

Clone the repository:

```
git clone https://github.com/EnigmaCurry/daw.git ~/git/vendor/enigmacurry/daw
```

Create a new alias that points to the project directory containing the Dockerfile:

```
DAW_HOME=${HOME}/git/vendor/enigmacurry/daw
DAW_PROJECT=sampler
DAW_SAMPLES=${HOME}/Samples
alias daw='shell_container docker=podman template=daw buildsrc=${DAW_HOME} docker_args="-v ${DAW_SAMPLES}:/daw/samples --volume=/run/user/$(id -u)/pulse:/run/user/1000/pulse" shared_volume=${HOME}/git/vendor/enigmacurry/daw shared_mount=/daw workdir=/daw/projects/${DAW_PROJECT}'
```

The arguments explained:

 * `docker=podman` - This uses Podman instead of Docker to create the container
 * `template=daw` - The name of the template. The name of the Dockerfile used to
   build the image is normally derrived from this template name, however in this
   case, because `buildsrc` is specified explicitly, the template name can be
   anything you want.
 * `buildsrc` - This overrides the build context directory or URL to use as the
   project root instead of the default [images/TEMPLATE](images) directory.
 * `dockerfile` - This overrides the path to the Dockerfile used to build the
   image.
 * `docker_args` - These are any extra `docker run` arguments that you want to
   specify. In this case, it is to mount the pulseaudio socket, and to mount an
   additional samples directory. Remember to wrap the value in double quotes
   becuase it contains spaces.
 * `shared_volume` - This shares the project directory from the host with the container
 * `shared_mount` - This mounts the shared volume at `/daw` inside the container
 * `workdir` - This starts the shell from the directory `/daw/projects`

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
