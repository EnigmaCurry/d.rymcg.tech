# Running d.rymcg.tech in a containerized shell

I am working on a [containerized Bash shell
environment](https://github.com/EnigmaCurry/d.rymcg.tech/pull/32) for
d.rymcg.tech, so that your only system requirement for running it is
Docker itself. All the command line tools you need are preinstalled in
the container.

So you'll be able to run a container straight with Docker, eg:

```
# Start an interactive Bash terminal in a container:
# Example; doesn't work yet
docker run --rm -it \
    --name nix-user \
    --hostname nix-user \
    -v nix-user:/home/nix-user \
    rymcg-tech/nix-common:v0.0.1
```

Inside the container you would have an SSH client, and docker command
(client) installed, with d.rymcg.tech pre-git-cloned to
`~/git/vendor/enigmacurry/d.rymcg.tech`, the bash shell setup for the
`d.rymcg.tech` CLI script, and all is left for you to do is setup your
docker (SSH) context just like with regular d.rymcg.tech, and the
entire home directory (along with all your `.env` files) stored as a
docker volume.

But I think its useful to still install d.rymcg.tech natively, this
lets you manage multiple environments at the same time. Here's the
interface I'm suggesting for it (unimplemented). The UI is arguably
the most important part:

```
[ryan@t440s nix]$ d.rymcg.tech
## Main d.rymcg.tech sub-commands - Optional arguments are printed in brackets [OPTIONAL_ARG].
...
shell [help]                  Containerized Bash shell environments, preconfigured as a Docker development workstation.
shell build                   Build the base docker images for the shell environments.
shell pull                    Pull the tagged base docker images from the regisry (so you don't have to build it).
shell run [INSTANCE] [TTY]    Start a shell terminal, for a given instance, and unique terminal TTY name.
shell attach [INSTANCE] [TTY] Attach to a running shell, for a given instance, and terminal TTY name.
                              (The INSTANCE name corresponds with the shared volume;
                              and the TTY name with the container that mounts it.)
shell ls                      List all running shell environment containers.
shell volume [ls]             List all shell environment volumes (including mounted and unmounted).
```

The fundamental identity of any of the many shell environments is the
*volume*, not the container. The containers are ephemeral, and they
are intended to be run in the foreground. Just quit the container Bash
shell with `Ctrl-D` and the container will self-destruct, but the
volume remains, so it can be restarted again, with all the same files
in the home directory. In order to add programs to the environment,
you must rebuild the base images, otherwise programs that you install
in the container are gone the next time you start.

Docker natively has the ability to attach to containers with [`docker
attach`](https://docs.docker.com/engine/reference/commandline/attach/),
and you can even do this multiple times, and run the same terminal
session from multiple windows (a bit like having `screen` or `tmux`,
but builtin to Docker itself). This is what the `shell attach` uses
too. Once attached, there is a key combination that can detach:
`Ctrl-P Ctrl-Q`. Once detached, the Bash shell is still running, and
so is the container. It can be reattachd at will, but as soon as you
end Bash, the container stops and is automatically removed (but the
volume and its data persist).

Having d.rymcg.tech installed natively, implies that you have some
docker context to run it on. But I envision the use of that docker
context as being exclusive to running shell environments, and that
those shell environments would manage *other* Docker hosts. So for
example, your laptop shouldn't have a Docker context to your
production web server, but only the container has one, because it
stores the SSH key for it.

Keeping your production docker context in a container, lets you turn
it off, and lockdown access. *To prevent access, you can simply turn
the docker server running your shell environments off*. This server
could be a VM running on your laptop or as a seperate device like a
raspberry pi (in either case, use an encrypted file system, to keep
secrets safe when offline, or if physically stolen.)

[See these instructions for creating an encrypted Docker server on a
raspberry
pi.](https://gist.github.com/devgioele/e897c341b8d1c18d58b44ffe21d72cf6)
