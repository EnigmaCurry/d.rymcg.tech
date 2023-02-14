# nix-user

This is a containerized "workstation" for
[d.rymcg.tech](../../README.md). You can create this as an admin
container to manage *other* docker hosts with d.rymcg.tech. This keeps
your .env files seperate per admin container (ie. one admin container
per docker context to manage).

You will need to setup [d.rymcg.tech](../../README.md) on at least one
workstation, so that you can build a docker image.

# Config

```
# If you want configure the 'default' instance:
make config

# If you want to configure a named instance:
make instance
```

# Build

```
make build
```

# Run image directly

`make build` will build the image named `nix-nix-user`. You can push
(and retag) this image onto a docker registry, so you can pull and run
it on any machine, without needing d.rymcg.tech setup.

```
docker run -d --name docker-admin-1 -v docker-admin-1:/home/nix-user nix-nix-user
```

And to attach to it:

```
docker exec -it docker-admin-1 bash
```

This example names the container and the volume `docker-admin-1`, but
you can name these however you wish.

# Install

If you have an existing d.rymcg.tech installation, you can run it with
the Makefile instead:

```
make install
```

# Shell

```
make shell
```

# Setup

One you've attached to the shell, you should find that the
[d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech) git
repository has been automatically cloned to
`/home/nix-user/git/vendor/enigmacurry/d.rymcg.tech`. The eponymous
[`d.rymcg.tech`](../../README.md#using-the-drymcgtech-cli-script-optional)
command line script is pre-installed on the `PATH`.

You now need to create your ssh keys, ssh config file, and create your
remote docker contexts.

# Uninstall

You can stop and remove the container, without destroying any of the
data that is stored in the home directory (the contents of
`/home/nix-user` are stored in an named volume `nix_user-home`)

```
make uninstall
```

# Destroy

To destroy the container and ALL data:

```
make destroy
```
