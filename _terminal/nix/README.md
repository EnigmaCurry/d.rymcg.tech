# nix-user

This is a containerized pet "workstation" based upon the
[nix](https://nixos.org/) package manager and
[home-manager](https://github.com/nix-community/home-manager#readme).
You can run your entire Docker development environment inside of this
container, or you can use a hybrid configuration where you still use a
text editor on your localhost workstation, and synchronize development
files into the container volume on the fly.

This container can be useful for running
[d.rymcg.tech](../../README.md) and keeping several isolated
environments for managing *other* Docker hosts.

This README assumes you have already installed
[d.rymcg.tech](../../README.md) on your host workstation. Once
installed, use your terminal and change to this directory:

```
## After you install d.rymcg.tech ...
cd ~/git/vendor/enigmacurry/d.rymcg.tech/_terminal/nix
```

## Config

```
# If you want configure the 'default' instance:
make config

# If you want to configure a named instance:
make instance
```

You will be asked to enter the SSH connection information for the
Docker host that this container will *manage* (*not* intended to be
the same docker server it is *deployed* on.) This information will be
used to automatically create the ssh config and docker context
(clients only).

## Build

```
make build
```

This will build the docker image, and apply all of the non-personal
config in [nixpkgs/base.nix](nix-user/nixpkgs/base.nix) as a cached
image layer (this will help speed up the image build process)

## Shell

There is no need to run `make install`, as there is no backend service
required. Simply start the shell on demand:

```
## Be patient, this takes awhile the first time:
make shell
```

The volumes for `/home/nix-user` (home directory) and `/nix` (the
user's nix store) are created during the initial build process, and
*copied* on first startup. Each instance is a "fat" copy. The `/nix`
volume especially is quite large (~2GB), and takes 1-2 minutes to
finish copying, so be patient. The volumes persist, so the startup
time will be much improved on the second time you run `make shell`.

The [entrypoint](nix-user/entrypoint.sh) is run on every startup, and
it will create the SSH keys (if needed), and clone the `d.rymcg.tech`
git repository (if not already), runs `home-manager switch`, and then
starts an interactive Bash shell. You can press `Ctrl-D` or type
`exit` to leave the shell.

You can run several independent shells at the same time (in separate
terminals), and each runs in a different container, but each instance
shares the same home directory and the same `/nix` store.

In order to run totally separate containers, with different data, you
must use separate instances. For that, use [`make
instance`](../../README.md#creating-multiple-instances-of-a-service).

## Setup

One you've attached to the shell, you should find that the
[d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech) git
repository has been automatically cloned to
`/home/nix-user/git/vendor/enigmacurry/d.rymcg.tech`. The eponymous
[`d.rymcg.tech`](../../README.md#using-the-drymcgtech-cli-script-optional)
command line script is pre-installed on the `PATH`.

SSH keys will be created automatically. These keys are added to the
keychain ssh-agent. The SSH config will be populated with your
`NIX_DOCKER_SSH_{HOST,USER,PORT}` details. The docker context will be
created for you.

To finish the docker client setup, you must manually copy the created
SSH public key, to your docker host's `.ssh/authorized_keys` file:

```
## Enter the shell with `make shell` and then copy this key
## to the *other* docker server's SSH authorized_keys file:
cat ~/.ssh/id_rsa.pub
```

Once the key is installed on the other server, you should now be able
to control that remote docker host from within this container:

```
## Test the remote docker context:
docker info
```

## Development

nix stores all the program data in `/nix`, and all configuration in
`/home/nix-user/.config/nixpkgs`. Because both of these directories
are mounted as docker volumes, you cannot simply rebuild the image to
load your development config, you must copy/delete the new/changed
files into the volume. There is a make target prepared to do just
that:

```
## Run this in another terminal, and leave it running:
make dev-sync
```

While the `dev-sync` process remains running, the files in the
[nixpkgs](nix-user/nixpkgs) directory on your local workstation will
be watched for any modification, and will be automatically
synchronized to the container volume, when they are changed.

You can now modify any file in [nixpkgs](nix-user/nixpkgs) and simply
restart the shell again:

```
### Leave the previous container shell with Ctrl-D.
### To load the new config, restart it again:
make shell
```

## Destroy

To destroy all the data for the current instance, run:

```
## Delete the instance volumes for /home/nix-user and /nix
make destroy
```

