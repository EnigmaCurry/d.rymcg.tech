# Docker Workstation Container

This is an Arch Linux based development container for
[d.rymcg.tech](d.rymcg.tech). Install this on a secure Docker server,
and you can use this as your remote Docker workstation. All of your
d.rymcg.tech files will live inside this container (or its volumes).
You can setup access for all of your Docker server instances to be
exclusively controlled through this container workstation, via SSH. By
storing inside this container, all of the environment files, secrets,
and authentication tokens, you can prevent leaking these secrets to
your normal laptop/workstation filesystem.

Once you've configured this container to be the sole docker client for
your digital empire, locking down access is trivial: simply turn off
this container, and only turn it back on when you need to perform some
maintainance.

It is recommended to install this on a secure Docker server that is
*separate* from your production Docker servers. Although this
container is protected by an SSH key (and SSH passwords are disabled),
you may want to layer more security, by running this on a private LAN,
not accessible from the internet, or from inside of a VPN.

## Config

```
make config
```

Enter the information asked:

 * `DOCKER_WORKSTATION_HOSTNAME` - the hostname for the new container
 * `DOCKER_WORKSTATION_USERNAME` - the username for the new user account inside the container
 * `DOCKER_WORKSTATION_AUTHORIZED_KEY` - the SSH public key to authorized access

You should already have an SSH key on your normal laptop/workstation.
If not, run `ssh-keygen`. Copy the public key (eg. from
`~/.ssh/id_rsa.pub`) and set it as `DOCKER_WORKSTATION_AUTHORIZED_KEY`. (The
key should be one long line like `ssh-rsa AAAAA...` or
`ecdsa-sha2-nistp256 AAAA...`)

## Build

This is a *fat* container, which contains dozens of preinstalled Arch
Linux packages, comprising a full Docker and Emacs development
environment, as well as the Firefox web browser. It could take up to
10 or 20 minutes to build everything. This is Arch Linux, so you are
recommended to build this image yourself, thereby downloading the
latest packages. (This is why this container is not provided as an
image you can pull from a registry: A variation on this could be made
upon a non-rolling release like Debian, and published as a semi-static
image. But for Arch Linux, I think this would be an anti-pattern; you
should build it yourself, fresh, but you could then publish your
custom image to make it easier for yourself to re-use).

The image includes all of the depenencies you will need for a Docker
client, d.rymcg.tech, and a full Emacs and web browser develoment
environment. You will be able to connect to the container via SSH,
enable X11 forwarding, and able to run its graphical applications (eg.
Emacs and Firefox) remotely from your local client computer. Although
Emacs can also be used from a terminal user interface (`emacs -nw`),
having a fully graphical Firefox allows you to do maintainance tasks
like view the Traefik dashboard (which is not normally accessible,
except through local SSH forward. X11 forwarding allows you to view
the dashboard from a third device, your client laptop).

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

You may want to create an SSH config entry in your `~/.ssh/config`
file:

```
# Put this in ~/.ssh/config:
# Name the Host whatever you want:
Host docker-workstation
    # Enter the real IP address or the DNS name of the Docker host:
    Hostname x.x.x.x
    # Enter the external SSH port forwarding to the container port 22:
    Port 2222
    # Enter the username configured for the workstation container:
    User user
    # Enable SSH connection sharing:
    ControlMaster auto
    ControlPersist yes
    ControlPath /tmp/ssh-%u-%r@%h:%p
```

With the config in place, you can connect directly:

```
ssh docker-workstation
```

## Emacs

This container includes my own custom [Emacs
enviornment](https://github.com/enigmacurry/emacs#readme), which you
can configure to use your own config (and git repository), or if you
don't want to use Emacs, you can disable it entirely in the config.

## Custom Packages

If you don't want to use Emacs, you can install whatever editors you
want, from the Arch Linux repositories. You can also install whatever
other packages you want, fully customizing your own image.

There are three important config variables related to packages:

 * `DOCKER_WORKSTATION_ARCH_MIRROR` this is the Arch Linux package
   repository (mirror) - you should customize this for a fast local
   mirror for your location, choose from the [the global mirror
   list](https://archlinux.org/mirrorlist/all/).
 * `DOCKER_WORKSTATION_BASE_PACKAGES` this is a list of all the
   packages that should be installed in the base layer of the image.
 * `DOCKER_WORKSTATION_EXTRA_PACKAGES` this is a list of all the
   additional packages that should be installed at the end of the
   image. When you want to test a new package, add them to the extra
   list, and rebuild the image (the build will be faster than adding
   it the the base list). You can consider moving these packages into
   `DOCKER_WORKSTATION_BASE_PACKAGES` later after you are done testing
   them, and you want to bake them into the image permanently (giving
   the build more efficient storage).
