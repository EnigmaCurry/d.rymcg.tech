# Localhost Docker on KVM Virtual Machine

Run Docker in a KVM (qemu) Virtual Machine as a systemd service on your local
workstation.

## Background

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
installer, in order to provision a new Docker server in a VM.

## Notices

This will run a docker server in a virtual machine on your localhost. By
default, only localhost can access the Docker services, but it can also be
configured to forward external connections from your LAN/router, if you wish
(`HOSTFWD_HOST='*'`).

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
sudo pacman -S docker make qemu python3 openssl curl gnu-netcat
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

You can change any of the config values you need by setting these environment
variables (or hardcoding these values at the top of the Makefile):

 * `VMNAME` - the name of the VM
 * `DISTRO` - the debian distribution name (eg. bullseye, buster, jessie)
 * `DISK` - the size of the VM disk image (eg. `20G`)
 * `MEMORY` - the size of the RAM in MB (eg `2048`)
 * `SSH_PORT` - the external SSH port mapped on the Host (eg `10022`)
 * `TIMEZONE` - the VM timezone (eg. `Etc/UTC` , `America/Los_Angeles`)
 * `EXTRA_PORTS` - the extra TCP ports (besides SSH) to map to the host. For
   example, `8000:80,8443:443` will map two external ports 8000 and 8443 to
   internal ports 80 and 443 respectively.
 * `DEBIAN_MIRROR` - the Debian mirror to install from.
 * `HOSTFWD_HOST` - the IP address of the host to serve on (default `127.0.0.1`,
   set to `*` to listen on all network interfaces.)
 
## Create the Docker VM

Run: 

```
make
```

This will create the VM disk image (`./VMs/docker-vm.qcow`) and automatically
install Debian from scratch using the minimal netboot installer, install Docker,
and boot the VM for the first time after install.

You can use this same command to restart the VM if it is ever shutdown. (It will
not attempt to reinstall if the existing disk image is found.)

*Note*: this process is designed to run and block until the VM is shutdown. 


Wait until you see the text `Booting Docker VM now ...`, leave it running, and
open a new terminal session to follow the next steps.

Switch your local docker context to the new VM:

```
docker context use docker-vm
```

Now you should be able to control the remote Docker server using the local
Docker client. Try running this from your workstation:

```
docker info | head
```

(You should see the name of the VM in the `Context` line at the start of the
output.)

You should be able to run any docker commands now, try:

```
docker run hello-world
```

If you need to SSH to the VM (you shouldn't normally), you can:

```
ssh docker-vm
```

## Install the systemd service and optionally start on boot

You can more easily control the VM by installing the systemd service:

```
make install
```

(If you have not enabled [systemd
"lingering"](https://wiki.archlinux.org/title/Systemd/user#Automatic_start-up_of_systemd_user_instances)
on your account before, this will fail, and a message will be printed to tell
you how to enable this.)

This will create a systemd unit for your current (unprivileged) user account, in
`~/.config/systemd/user/docker-vm.service`.

You can now interact with systemd to control the service:

```
# Start:
systemctl --user start docker-vm

# Stop (probably not a clean shutdown!):
systemctl --user stop docker-vm

# Enable at boot:
systemctl --user enable docker-vm

# Disable at boot:
systemctl --user disable docker-vm

# See status:
systemctl --user status docker-vm

# See logs (there aren't any):
journalctl --user --unit docker-vm
```

You can also use the Makefile targets that are aliases for the above systemctl
commands:

```
make start
make stop
make enable
make disable
```

## Firewall

By default, all of the TCP ports that are listed in the Makefile (including
`SSH_PORT` and `EXTRA_PORTS`) are exposed only to your localhost
(`HOSTFWD_HOST='127.0.0.1'`). This prevents other hosts on your LAN (or from
your router) from accessing your private Docker VM.

This is configurable. If you wish, you can expose your Docker VM publicly to
your LAN. Set `HOSTFWD_HOST='*'`. There is a preconfigured Makefile target to do
this, just run `make docker-vm-public` (instead of `make docker-vm`.)

You can install `ufw` to use as a simple firewall to open ports selectively, and
to protect your entire workstation. The default settings for `ufw` will disable
all external inbound connections (and allow all outbound connections). Simply
install and enable ufw:

```
## 'pacman -S ufw' or 'apt install ufw'
sudo ufw enable
```

To open specific ports publicly (eg. `5432`):

```
sudo ufw allow 5432
```

(Note to careful readers: [ufw is not safe to use on the same host operating
system as Docker](https://github.com/chaifeng/ufw-docker#problem), but since
Docker is running in a VM, and ufw is running on the host, this is fine.)

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

