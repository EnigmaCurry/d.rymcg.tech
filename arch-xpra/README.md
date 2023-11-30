# Docker Workstation Container

This is an Arch Linux based development container for
[d.rymcg.tech](d.rymcg.tech). Install this on a secure Docker server,
and you can use this as your remote Docker workstation. All of your
d.rymcg.tech environment and files will live inside this container (or
its volumes). You can setup access for all of your Docker server
instances to be exclusively controlled through this container
workstation, via SSH. By storing inside this container, all of the
environment files, secrets, and authentication tokens, you can prevent
leaking these secrets to your normal laptop/workstation filesystem.

Once you've configured this container to be the sole docker client for
your digital empire, locking down access is trivial: simply turn off
this container, and only turn it back on when you need to perform some
maintainance.

It is recommended to install this on a secure Docker server that is
*separate* from your production Docker servers. Although this
container is protected by SSH keys (and SSH passwords are disabled),
you may want to layer more security, by running this on a private LAN,
not accessible from the internet, or from inside of a VPN.

## Config

```
make config
```

Enter the information asked:

 * `ARCH_XRPA_HOSTNAME` - the hostname for the new container
 * `ARCH_XPRA_USERNAME` - the username for the new user account inside the container
 * `ARCH_XPRA_AUTHORIZED_KEY` - the SSH public key to authorized access

You should already have an SSH key on your normal laptop/workstation.
If not, run `ssh-keygen`. Copy the public key (eg. from
`~/.ssh/id_rsa.pub`) and set it as `ARCH_XPRA_AUTHORIZED_KEY`. (The
key should be one long line like `ssh-rsa AAAAA...` or
`ecdsa-sha2-nistp256 AAAA...`)

## Build

This is a *fat* container, and could take up to 10 or 30 minutes to
build. It includes all of the depenencies you will need for a Docker
client, d.rymcg.tech, and a full Emacs and web browser develoment
environment. You can connect to the container via SSH, enable X11
forwarding, and you will be able to run its graphical applications
(eg. Emacs and Firefox) remotely from your local client computer.
Although Emacs can also be used from a terminal user interface (TUI),
having a fully graphical Firefox allows you to do maintainance tasks
like view the Traefik dashboard (which is not normally accessible,
except through local SSH forward.)

Building will install the entire Emacs environment, and this takes
several minutes, so it is recommended to run the build step first,
before you install:

```
## Build the image - be patient!
make build
```

## Install

Once you have built the image, you can install it:

```
make install
```

## Connect to it via SSH

```
make shell
```

This will connect to the container via SSH (on port 2222 by default)
