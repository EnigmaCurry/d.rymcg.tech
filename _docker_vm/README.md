# Localhost Docker on KVM Virtual Machine

I don't think its wise to run the Docker daemon natively on your workstation's
host operating system. Granting your user into the `docker` group is basically
giving your user full root access to your host operating system (without even
needing a password!). Running docker via sudo is also unwieldy. This project
encourages you to run your Docker server remotely and using your local docker
client to access it over a remote (SSH) context. Yes, you will still essentially
have full root access of *that* whole server, but if that server is dedicated
only for docker purposes, that seems fine to me. For production, you will just
want to make sure you use a secure workstation (or CI) to set that up.

But maybe you don't have a server yet, and you may want to start development on
your laptop before even thinking about setting one up. In that case, the
recommendation is to run Docker inside of a Virtual Machine (VM) and connect to
it just like you would a remote Docker server. This exact recipe is used for the
MacOS and Windows Docker Desktop versions, so if you're using Docker Desktop on
a non-Linux computer, you can quit reading this, you're already running Docker
in a VM.

This guide is for Linux workstation users only! This will show you how to
automatically install a new KVM virtual machine with the Debian minimal netboot
installer, in order to provision a new Docker server in a VM. (This is also a
generic way of installing a Debian VM without Docker, see the Customize section
for that.)

## Notices

This will run a private docker server in a virtual machine on your localhost. No
external network will be able to access your VM network. Docker ports are
exposed to the workstation localhost only.

The parent project (d.rymcg.tech) includes a Traefik configuration which uses
Let's Encrypt with the TLS (TLS-ALPN-01) challenge type. This configuration will
only work when your Docker server has an open connection from the internet on
TCP port 443. This will not be the case in a typical development environment, so
the TLS certificates will be improperly issued (Traefik default self-signed
cert) for the containers inside the Docker VM. (If you don't need a browser, you
can still test your APIs with `curl -k` to disable TLS verification.)

You can still use all of the projects that do not use TLS, or for those projects
that include their own self-signed certificates (eg.
[postgresql](../postgresql)).

To get around this problem, you may reconfigure
[Traefik](../traefik/docker-compose.yaml) to use the DNS-01 challenge type, and
this challenge type works behind a firewall too. The details for setting this up
is outside the scope of this documentation at this time.

One day, this project may incorporate
[Step-CA](https://smallstep.com/docs/step-ca) which would allow the creation of
an offline/private ACME server to replace the role of Let's Encrypt in a
development environment, but that work has not been done yet.

## Workstation dependencies

### Arch Linux

```
sudo pacman -S docker make qemu python3 openssl curl
```

### Ubuntu

[Follow the guide to install the docker engine on
Ubuntu](https://docs.docker.com/get-docker/) (Make sure to follow this guide so
that you install the most up to date version of docker directly from Docker's
package repository, not the default Ubuntu one. You don't need to start the
daemon on your workstation, you only need the `docker` cli client.)

Also install the following:

```
sudo apt-get install make qemu-utils qemu-system-x86 qemu-kvm curl python3 openssl
```

## Review the config in the Makefile

Look at the [Makefile](Makefile) and find the `docker-vm` target. You can change any of the config values you need:

 * `VMNAME` - the name of the VM
 * `DISTRO` - the debian distribution name (eg. bullseye, buster, jessie)
 * `DISK` - the size of the VM disk image (eg. `20G`)
 * `MEMORY` - the size of the RAM in MB (eg `2048`)
 * `SSH_PORT` - the external SSH port mapped on the Host (eg `10022`)
 * `TIMEZONE` - the VM timezone (eg. ``Etc/UTC` , `America/Los_Angeles`)
 * `EXTRA_PORTS` - the extra TCP ports (besides SSH) to map to the host. For
   example, `8000:80,8443:443` will map two external ports 8000 and 8443 to
   internal ports 80 and 443 respectively.
 * `DEBIAN_MIRROR` - the Debian mirror to install from.

## Create the Docker VM

Run: 

```
make docker-vm
```

This will create the VM disk image (`./VMs/docker-vm.qcow`) and automatically
install Debian from scratch using the minimal netboot installer, and will then
boot the VM and install docker.

You can use this same command to restart the VM if it is ever shutdown. (It will
not attempt to reinstall if the existing disk image is found.)

Once finished, switch your local docker context to the new VM:

```
docker context use docker-vm
```

Now you should be able to use Docker locally, try:

```
docker info | head
```

(You should see the name of the VM in the `Context` line at the start of the
output.)

If you need to SSH to the VM (you shouldn't normally), you can:

```
ssh docker-vm
```

## Make other Debian VMs (optional)

See the included [Makefile](Makefile) at the bottom are some example VMs
predefined. You can add your targets, following the `my-bullseye` example. You
can customize the names, disk size, memory etc. You can create several VMs with
the same Makefile, just make sure that each VM you create has a unique Makefile
target, `VMNAME`, and `SSH_PORT`.

To start the example `my-bullseye` VM target (No docker installed), run:

```
make my-bullseye
```

This will create the VM disk image (`./VMs/my-bullseye.qcow`) and automatically
install Debian from scratch using the minimal netboot installer.

Once the installer is finished, the VM will be booted automatically, and you an
SSH host entry will be added to your config file (`~/.ssh/config`).

Connect to the VM once it has started:

```
ssh my-bullseye
```

## Customize the preseed.cfg file (optional)

The [preseed.cfg](preseed.cfg) is the configuration for the automated
debian-installer. The file is a template file that includes variable names that
are replaced via `envsubst`. You can customize this file however you wish to
change how the installer behaves.

## Credits

The `build_qemu_debian_image.sh` script is a fork from Sylvestre Ledru
(sylvestre) and Hugh Cole-Baker (sigmaris):

 * [opencollab/qemu-debian-install-pxe-preseed](https://github.com/opencollab/qemu-debian-install-pxe-preseed)
 * https://sigmaris.info/blog/2019/04/automating-debian-install-qemu/
([gist](https://gist.github.com/sigmaris/dc1883f782d1ff5d74252bebf852ec50))

I did not find any license for these prior works, but I assume republishing this
here is still in good faith. Thank-you!

