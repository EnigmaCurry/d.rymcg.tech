# Create a "pet workstation" development container with `d.rymcg.tech`

`d.rymcg.tech` has support for creating containerized "pet"
workstation development environments, which you can use for all of
your Docker development and deployment needs, which helps to keep
various project files separate, and to compartmentalize/secure the
secrets stored in your project's `.env` files.

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

