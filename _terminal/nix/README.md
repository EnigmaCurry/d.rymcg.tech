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

## Build

```
make build
```

This will build the docker image, and apply all of the non-personal
config in [nixpkgs/common.nix](nix-user/nixpkgs/common.nix). The
personalized configuration is applied later on, during the shell
startup.

## Shell

There is no need to run `make install`, as there are no backend
services required. Simply start the shell on demand:

```
## Be patient, this takes a few minutes the first time:
make shell
```

This creates volumes for `/home/nix-user` (the user's home directory)
and `/nix` (the user's nix store) and these are pre-populated with
data generated from the image, which is *copied* on first startup.
Each instance is a "fat" copy of the data from the image. The `/nix`
volume especially is quite large (~2GB), and takes 1-2 minutes to
finish copying on first start, so please be patient. The volumes will
persist, so the startup time will be much improved for the second time
you run `make shell`.

The [entrypoint](nix-user/entrypoint.sh) is run on every startup, and
it will create the SSH keys (if needed), and clone the `d.rymcg.tech`
git repository (if not already), runs `home-manager switch`, and then
starts an interactive Bash shell. You can press `Ctrl-D` or type
`exit` to leave/shutdown the shell.

You can run several independent shells at the same time (in separate
terminals), and each runs in a different container, but each instance
shares the same home directory and the same `/nix` store.

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

