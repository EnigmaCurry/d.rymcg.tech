# Create a "pet workstation" development container with `d.rymcg.tech`

`d.rymcg.tech` has support for creating containerized "pet"
workstation development environments, which you can use for all of
your Docker development work and/or deployment contexts, which helps
to keep various project files separate, and to compartmentalize access
to your production Docker servers, and to guard secrets stored in
`.env` files.

There are two methods for creating these containers, which you can
choose depending on your needs:

 1. Install
   [d.rymcg.tech](https://github.com/enigmaCurry/d.rymcg.tech) the
   normal way, by cloning the repository to your native
   workstation, and installing the eponymous [`d.rymcg.tech` CLI
   script](README.md#using-the-drymcgtech-cli-script-optional). With
   this method you can build and rebuild the containers from scratch,
   and have full control over the container configuration.

 2. Run directly from a pre-built docker image, pulled from the docker
    registry. This method requires no other dependencies beside Docker
    itself, which offers nearly the same level of configuration inside
    the container, but does not allow for rebuilding the base image
    itself.

## Install with the `d.rymcg.tech` CLI script

Initial setup requires you to install [d.rymcg.tech](README.md) the
normal way, by creating a Docker host, and an SSH connection context,
and cloning the source code to your native workstation. Follow the
steps for [installing the CLI
script](README.md#using-the-drymcgtech-cli-script-optional), and add
the Bash shell completion support to your `~/.bashrc`.

Once installed on your native workstation, you can use the
`d.rymcg.tech` script to create your pet development containers:

 * Choose a short instance name for your pet container. The example
   will use `foo`.
 * Edit your `~/.bashrc` file again, and underneath the configuration
   for `d.rymcg.tech`, add the following alias:

```
## This part should exist already, when you installed the d.rymcg.tech script:
export PATH=${PATH}:${HOME}/git/vendor/enigmacurry/d.rymcg.tech/_scripts/user
eval "$(d.rymcg.tech completion bash)"

## Add this alias to create a pet container alias called `foo`:
__d.rymcg.tech_shell_alias foo
```

 * Restart your Bash shell, and now you have access to the `foo`
   alias.

With the `foo` alias, you can create multiple shell `TTY` containers,
these containers give you an interactive shell terminal environment.
Every container that you create with the `foo` alias will share the
same home directory mounted from a volume.

You can bootstrap the `foo` container simply by typing `foo`. This
will configure, build, start, and attach to the new container.

Example command list:

```
## foo [TTY] --args ...

foo                           Configure, Build, Start, and Attach to the `nix-foo-1` container on TTY '1'.
foo 2                         Configure, Build, Start, and Attach to the `nix-foo-2` container on TTY '2'.
foo --help                    Show this help message.
foo --config                  Create/Edit the foo instance `.env_{DOCKER_CONTEXT}_{INSTANCE}` config file.
                              (The .env file is saved to /home/ryan/git/vendor/enigmacurry/d.rymcg.tech/_terminal/nix)
foo --clean                   Delete the foo instance `.env_{DOCKER_CONTEXT}_{INSTANCE}` config file.
foo --build                   Build the container images for the foo instance.
foo --start                   Start the `nix-foo-1` instance container in the background on TTY '1'.
foo --stop                    Stop the container of the foo instance on TTY '1'.
foo bar --start               Start the `nix-foo-bar` instance container in the background on TTY 'bar'.
foo bar --restart             Stop and Restart the foo instance container in the background on TTY 'bar'.
foo --destroy                 Destroy ALL of the foo instance containers and the home directory volume.
foo --status                  Show all of the running foo instance TTY containers.
foo --sync                    Synchronize the local nixpkgs config to the foo instance volume.
foo --dev-sync                Continuously synchronize the local nixpkgs config to the foo instance volume.
```

The shell containers are designed to be long running processes, which
you can attach and deatch from at will.

To detach from the container, press the key combination `Ctrl-\`
(press the `Control` key and the `\` key simultaneously.) You can then
reattach to the container again by simply running `foo`.

You can create as many shell aliases as you wish:

```
## Create the `baz` instance alias:
__d.rymcg.tech_shell_alias baz
```

The `baz` instance is entirely separate from the `foo` instance, using
a different volume for the home directory.

## Install with a pre-built docker image

TODO.

## Secure access to the Docker API (socket)

These pet containers can be used as part of a layered security
protocol for accessing/modifying your production Docker servers.

Consider how you access your own Docker server: if you have followed
all of the [guidelines for creating a Docker
host](https://github.com/EnigmaCurry/d.rymcg.tech#create-a-docker-host),
then you will have created a Docker server that is remotely controlled
over SSH using the `root` user account on the server.

The usage of `root` is (mostly) unavoidable, due to the design of
Docker (anyone able to use the Docker API is able to execute commands
as the same user running the Docker daemon, which is
[[almost](https://docs.docker.com/engine/security/rootless/)] always
`root`). Likewise, when using a different account that has been added
to the system `docker` group, it is the same thing as if being given
access to `root`, without even needing a password! Therefore, securing
access to the Docker API is imperative!

By default, a Docker server does not expose its socket over the
network, however it can be accessed remotely through SSH. So the
security of the socket comes down to the security of your SSH keys. If
you leave your SSH keys unprotected, anyone with access to those keys
can modify your Docker server. Leaving unprotected SSH keys to your
produciton server, laying around on your single-user laptop, is
probably unwise.

One method for securing various SSH keys, is to use separate system
accounts on your workstation (laptop). That way, your regular user
(uid=1000), cannot access the files of the production user account
(uid=1001). This is cumbersome, because you will need to switch
accounts to maintain different systems, so you will likely need to use
*another* system account that can manages access to these accounts
(via `sudo`). Make sure your laptop has full disk encryption for
security *at rest*.

The proposed, alternative strategy, is to use these pet containers
instead of regular system accounts. Each pet container will have a
separate clone of d.rymcg.tech source code, and configure their own
SSH (client) access to your production Docker hosts. Configured
appropriately, each container will only be able to access a limited
number of Docker contexts under their purview.

To control access, you need at least *two* docker servers, preferably
running on different hosts:

```
  Your laptop -> connects over SSH to ...
     Docker server #1 running the pet container -> connects over SSH to ...
       Real Docker server #2 running your production workloads.
```

You can use your normal workstation account to attach to these pet
containers, and do whatever work you need inside them. To secure
access, when you're done using them for the time being, is simple:
just turn off the Docker server that runs the pet container!

If only the pet container has access to your production docker server,
and if that pet container is offline, then that means that you can't
access the production server. Simple! If you use an *encrypted*
filesystem on your Docker server (`#1`, running the pet container),
that requires a secure passphrase entered on boot, then the access of
your SSH keys is safe *at rest* (ie. when the server is turned off, or
if the the server is unplugged and stolen.)

You don't need a very powerful machine to run the pet containers, any
arm64 raspberry pi or similar device will work. Having a seperate
device makes it easy to turn it on and off and disconnect it. See
these [instructions for creating a raspberry pi running an encrypted
root filesystem, with remote SSH
unlock](https://gist.github.com/devgioele/e897c341b8d1c18d58b44ffe21d72cf6).
Also see the general instructions in
[RASPBERRY_PI.md](RASPBERRY_PI.md) for installing Docker.
