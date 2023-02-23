# nix-user

This is a containerized, pet "workstation", based upon the
[nix](https://nixos.org/) package manager, and
[home-manager](https://github.com/nix-community/home-manager#readme).
You can run your entire development environment inside of this
container's terminal, or you can use a hybrid configuration where you
still use a text editor and other tools on your local workstation, but
synchronize development files into the container volume, on the fly.

This container is useful for running things like
[d.rymcg.tech](../../README.md), for keeping several isolated
development/production environments, and for managing *other* Docker
hosts. (You can, technically, install this on the same Docker host
that it will also manage, but this would not be a good way to run a secure
production server, so it is recommended to only run this container
from a different [offline] Docker host.)

This README assumes you have already setup
[d.rymcg.tech](../../README.md) on your host workstation, and have an
existing docker context. Once you've installed this locally, use your
terminal and change to this directory:

```
## After you install d.rymcg.tech on localhost ...
cd ~/git/vendor/enigmacurry/d.rymcg.tech/_terminal/nix
```

## Use cases

The normal way to install [d.rymcg.tech](../../README.md) is to
install it on your workstation, and use it to control a remote Docker
server, through SSH. In that context, "workstation" is usually defined
as: the native Linux operating system of your laptop, running tools
under a regular user account, usually in the same graphical
environment that you use a web browser in. All development files,
source and config, are stored locally (eg. in
`~/git/vendor/enigmacurry/d.rymcg.tech`).

In the context of this document, "workstation" is defined a bit
differently: this containerized "workstation" is a terminal-only
interface that holds all development files and programs in a docker
volume. Inside the container, you have installed the docker client
program, and an ssh client, and a docker context is setup (the same
way it would be normally, by remote SSH) and you can control other
Docker hosts from within this container.

One of the prime reasons for using this is to keep the `.env` files
and all of the source code of a particular docker environment
completely separate from another. You might want to have one shell
container for development, and another for production.

Another reason to run this is to separate the client's access to
modify the server. If you install the docker SSH context directly onto
your local workstation, then anyone with local access to your SSH key
can modify your docker server. Alternatively, you could create a
bastion docker host, that only hosts these pet nix containers, and you
can configure your other Docker server to only allow admin access from
the bastion host. For example, you could simply turn off the bastion
host to deny all access, and only turn it on when you need to change
something. A great use for a small ARM64 raspberry pi.

## Run the prebuilt image from the registry with zero config

If you just want to run the prebuild image, you can do this straight
with docker, with nothing else required:

```
docker run --rm -it \
  --name nix-user \
  --hostname nix-user \
  -v nix-user:/home/nix-user \
  registry.digitalocean.com/rymcg-tech/nix-common:v0.0.1
```

This image has no user customization, but you can add it after the
fact. If you want to customize the image and build your own, keep
reading the next sections.

## Config

```
# If you want to configure the 'default' (unnamed) instance:
make config

# If you want to configure a named instance:
make instance
```

You will be asked to enter the SSH connection information for the
Docker host that this container will *manage* (*not* intended to be
the same docker server it is *deployed* on.) This information will be
used to automatically create the ssh config and docker context
(clients only).

## Build (or pull) the images

You can build the full image set locally:

```
## Build and retag images locally:
make build
```

Building creates three docker images:

 * base - the base image contains a base Debian OS with nix and
   home-manager preinstalled.
 * common - the common image contains all of the nix configuration
   from [nixpkgs/common.nix](nix-user/nixpkgs/common.nix), which
   installs all of the packages that a user may need, including the
   `d.rymcg.tech` CLI script. This does *not* include any
   user-personalized information.
 * user - the user image is the final layer, which includes the
   user-personalized configuration from
   [nixpkgs/user.nix](nix-user/nixpkgs/user.nix) (This image is
   generally not published, but built locally, on top of the base and
   common images.)

The nix build process is a bit heavy, and it may even fail, if you
have less than 8GB of memory (including swap). If you don't wish to
build the images locally, you can pull the pre-built base+common
images from the community public docker registry instead:

```
## Pull the tagged base+common images from the registry:
## NOTE: these images are not (yet) built automatically by CI and may be outdated:
make pull

## When you pull the base images, you still need to build the user image locally:
make build-user
```

## Shell

There is no need to run `make install`, as there are no backend
services required. Simply start the shell on demand:

```
make shell
```

This creates a named volume for `/home/nix-user` (the container user's
home directory) and is pre-populated with data generated from the
image, which is *copied* on first startup. This is a "pet" container
setup, where the contents of the home directory are divorced from the
image at the point of first creation, so even if you rebuild the
image, it won't affect the contents of the volume. To create a fresh
container, from scratch, you must use a new volume, or delete the old
one.

The [entrypoint](nix-user/entrypoint.sh) is run on every startup,
which runs `home-manager switch` which rebuilds all of the user
configuration, and then starts an interactive Bash shell. You can
press `Ctrl-D` or type `exit` to leave/shutdown the shell.

All of the nix program data is stored in `/nix` and it is important to
know that this directory is *not* saved in any volume. You may install
new programs as you wish, but unless you modify the base images, these
modifications are ephemeral, and are lost once the container exits.
This may be a useful feature, in order to try out new things, but you
will need to write them into your nix config, and run `make build`, to
make these changes permanent.

You can run several independent shells at the same time (in separate
terminals), and each runs in a different container, but each instance
shares the same home directory and the same `/nix` store. Since each
shell runs as a separate container, each session requires a unique
name: the default name is `1`, so if your instance is named `default`,
the first shell that you start will be named `nix-default-1`. To
create a second shell, using the same instance, you need to specify
the name:

```
## Specify a name for opening additional shells of the same instance:
make shell name=foo
```

In the example above, the new shell will start, and is named
`nix-default-foo`.

In order to run totally separate containers, with different data, you
must use separate instances. For that, use [`make
instance`](../../README.md#creating-multiple-instances-of-a-service).

## Setup

One you've attached to the shell, you should find the account is
automatically setup with the following:

 * A fresh SSH key has been created (`~/.ssh/id_rsa`). By default,
   there is no password for this key, but you may create a password
   for it, run: `ssh-keygen -p -f ~/.ssh/id_rsa`, and then keychain
   will ask you to reenter the password, each time you run `make
   shell`.
 * The SSH config file (`~/.ssh/config`) has been created from the
   information you gave during `make config` (host,username,port).
   `ssh-keyscan` has automatically created `.ssh/known_hosts`.
 * A remote docker context has been created, using the host in the SSH
   config. (`docker context ls`)
 * The [d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech) git
   repository has been automatically cloned to
   `~/git/vendor/enigmacurry/d.rymcg.tech`. 
 * The eponymous
   [`d.rymcg.tech`](../../README.md#using-the-drymcgtech-cli-script-optional)
   command line script is pre-installed, and available on the `$PATH`
   from any directory.
 * [EnigmaCurry's emacs config](https://github.com/enigmacurry/emacs)
   has been installed in `~/.emacs.d`

To finish the docker client setup, you must manually copy the created
SSH public key, to your other Docker host's `authorized_keys` file:

```
## Print the SSH key to copy it:
## Add it to your other docker host's authorized_keys:
cat ~/.ssh/id_rsa.pub
```

Once the key is installed on the other server, you should now be able
to control that remote docker context from within this container:

```
## Test that the remote docker context works:
docker run hello-world
```

## Development

nix stores all the program data in `/nix`, and all configuration in
`/home/nix-user/.config/nixpkgs`. Because both of these directories
are mounted as Docker volumes, you cannot simply rebuild the image to
load your development config (the volumes overlay the image), so you
must copy/delete the new/changed files into the existing volume. There
is a make target prepared to do just that:

```
## Run this in another terminal, and leave it running:
make dev-sync
```

While the `make dev-sync` process remains running, the files in the
[nixpkgs](nix-user/nixpkgs) directory on your local workstation will
be watched for any modification, and will be automatically
synchronized to the container volume, whenever changes occur. This is
a one-way sync from the workstation [nixpkgs](nix-user/nixpkgs)
directory to the container (at `.config/nixpkgs`). This also tracks
local deletions, so if a file is non-existant locally, it will be made
non-existent (deleted) in the container too.

You can now make local modifications to [nixpkgs](nix-user/nixpkgs)
and simply restart the shell again to reload your config:

```
### Leave the previous container shell with Ctrl-D.
### To load the new config, restart it again:
make shell
```

As an alternative to `make dev-sync`, you may use [Emacs
TRAMP](https://www.gnu.org/software/tramp/) to edit files in the
container directly from your workstation: install
[docker-tramp](https://github.com/emacs-pe/docker-tramp.el). Be
cautious with this method, and understand that your files are only
saved in the docker volume (persistent, but easy to delete/prune), and
if they are deemed important, they should be commited to a git
repository, or backed up somehow.

## Destroy

To destroy the container + volume data, for the current instance,
run:

```
## Delete the instance volumes for /home/nix-user and /nix
make destroy
```

