# Localhost Docker on KVM Virtual Machine

**Update**: [Docker Desktop](https://docs.docker.com/desktop) is now
available for all three major platforms: Linux, Windows, and Mac. So
for desktop users, you can use Docker Desktop instead of these
instructions. For command-line/headless/server installs, these
instructions are still working great.

Run a secure Docker environment in a KVM (qemu) Virtual Machine (VM)
as an unprivileged systemd user service on your local workstation (or
on a server). This is optimized for private localhost development
purposes, but can also be used to host public services for your LAN,
or to have multiple individual docker VMs on a single large server and
publish to the internet. This can be a good way of separating security
concerns, or for creating segmented namespaces like dev/test/prod, but
all colocated on the same physical server.

## Background

I don't think it's wise to run the Docker daemon natively on your
workstation's host operating system (especially not on the same system
that you run your web browser or other personal applications). If you
grant your user account into the `docker` group, it is basically
giving your user full root access to your host operating system
(without even needing a password!). Running docker via sudo is also
unwieldy. This project (d.rymcg.tech) encourages you to run your
Docker server remotely and using your local docker client to access it
over a remote (SSH) context. Yes, that means you will still
essentially have full root access of *that* whole server, but if that
server is dedicated only for your docker environment, that seems fine
to me. For production, you will just want to make sure you use a
secure workstation (or CI) to set that up.

But maybe you don't have a server yet, and you may want to start
development on your laptop before even thinking about setting one up.
(Or, you may have a server, but its already being used for other
non-docker things.) In that case, the recommendation is to run Docker
inside of a VM and connect to it just like you would a remote Docker
server. This exact recipe is used for Docker Desktop, so if you're
using Docker Desktop, you can quit reading this, you're already
running Docker in a VM.

This guide is for Linux workstation/server users only! This will show
you how to automatically install a new KVM virtual machine with the
Debian minimal netboot installer, in order to provision a new Docker
server in a VM, and installing a systemd User service to automatically
start the VM on system boot, as well as cleanly shutting down when
stopping the service.

## Notices

This will run a docker server in a virtual machine on your localhost.
By default, only localhost (`127.0.0.1`) can access the Docker
services, but this can also be configured to forward incoming
public/external connections from your LAN or wider internet (Set
`HOSTFWD_HOST='*'` or set a particular IP address of your network
interface).

This project is a sub-project of
[d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech#readme).
However, you can use this completely separately from it.

The parent project (d.rymcg.tech) includes a [Traefik
configuration](https://github.com/EnigmaCurry/d.rymcg.tech/tree/master/traefik)
which uses Let's Encrypt with the TLS challenge type
([TLS-ALPN-01](https://letsencrypt.org/docs/challenge-types/#tls-alpn-01)).
This configuration will only work when your Docker server has an open
connection from the internet on TCP port 443. This will not be the
case in a typical development environment, so the TLS certificates
would be improperly issued for the containers inside the Docker VM (in
that case you'd get a Traefik default self-signed cert). If you don't
need to use a webbrowser, you can still test your APIs with `curl -k`
to disable TLS verification, or your webbrowser might let you bypass
the self-signed certificate on a per-domain basis. You can still use
all of the projects that do not require TLS, or for those projects
that include their own self-signed certificates (eg.
[postgresql](../postgresql)).

To get around this TLS problem, you may reconfigure
[Traefik](../traefik/docker-compose.yaml) to use the [DNS-01 challenge
type](https://doc.traefik.io/traefik/user-guides/docker-compose/acme-dns/),
and this challenge type works from behind a firewall too. One day,
this project may incorporate
[Step-CA](https://smallstep.com/docs/step-ca) which would allow the
creation of an offline/private ACME server to replace the role of
Let's Encrypt in a development environment, but that work has not been
done yet.

## Workstation dependencies

You will need an SSH client with a configured SSH-agent with your key loaded.

You can double check that this is the case, this should print your current
loaded public key:

```
ssh-add -L
```

If you haven't setup your SSH key yet, you just need to run
`ssh-keygen` and follow the prompts. If you're not running a fancy
Desktop Environment that handles your SSH agent for you, check out
[keychain](https://wiki.archlinux.org/title/Keychain#Keychain) for an
easy to use ssh agent that works with all terminals and/or window
managers. Then retry the above command to make sure its working.

```
## Example keychain command to load the agent into the current terminal session:
eval `keychain --eval id_rsa`
```

### Arch Linux

If you are running Arch Linux, install these dependencies:

```
sudo pacman -S docker make qemu python3 openssl curl gnu-netcat socat
```

Arch linux doesn't start the docker daemon by default, which is what you want.
However, it can still be started manually. To prevent it from ever starting,
run:

```
sudo systemctl mask docker
```

### Ubuntu

If you are running Ubuntu, install the following:

```
sudo apt-get install make qemu-utils qemu-system-x86 \
     qemu-kvm curl python3 openssl socat
```

[Follow this guide to install the docker engine on
Ubuntu](https://docs.docker.com/engine/install/ubuntu/) (Make sure to
follow this guide for maximum feature compatibility, so that you
install the most up to date version of Docker directly from Docker's
package repository, not from the default Ubuntu repository. You don't
need to start the daemon on your workstation, you only need the
`docker` CLI client, but they are bundled in the same package.)

You should disable the docker daemon:

```
sudo systemctl disable --now docker
```

And prevent it from starting:

```
sudo systemctl mask docker
```

## Review the config in the Makefile

You can change any of the config values you need by setting these
environment variables (or by hardcoding these values at the top of the
Makefile, which become the default settings):

 * `VMNAME` - the name of the VM
 * `DISTRO` - the [debian distribution
   name](https://www.debian.org/releases/) (eg. bullseye, buster,
   jessie)
 * `DISK` - the size of the VM disk image (eg. `20G`)
 * `MEMORY` - the size of the RAM in MB (eg `2048`)
 * `SSH_PORT` - the external SSH port mapped on the Host (eg `10022`)
 * `TIMEZONE` - the VM timezone (eg. `Etc/UTC` , `America/Los_Angeles`)
 * `EXTRA_PORTS` - the extra TCP ports (besides SSH) to map to the host. For
   example, `8000:80,8443:443` will map two external ports 8000 and 8443 to
   internal ports 80 and 443 respectively.
 * `DEBIAN_MIRROR` - the [Debian
   mirror](https://www.debian.org/mirror/list) to install from.
 * `HOSTFWD_HOST` - the IP address of the host to serve on (default `127.0.0.1`,
   set to `*` to listen on all network interfaces.)

## Create the Docker VM

If you haven't already, clone this git repository to your workstation
and change to this directory (`_docker_vm`):

```
git clone https://github.com/EnigmaCurry/d.rymcg.tech.git \
    ~/git/vendor/enigmacurry/d.rymcg.tech
cd ~/git/vendor/enigmacurry/d.rymcg.tech/_docker_vm
```

Run:

```
# Run this inside the _docker_vm directory (where this same README.md exists):
make
```

This will create the VM disk image under this same directory
(`./VMs/docker-vm.qcow`) and automatically install Debian from scratch using the
minimal netboot installer and install Docker.

*Please Note*: Running `make` is designed to run *and block* your
terminal until the VM is deliberately shutdown. The VM will
automatically reboot after the install is complete and will then wait
at the VM login console. You won't be needing to use that console, so
just ignore it. Instead, you will use SSH in another terminal. Later
on, you can use systemd to install the service in the background and
automatically start it on host system boot.

Running `make` multiple times is safe, if the disk image is found, installation
is skipped. If you ever do want to start completely from the beginning, run
`make clean` first (this would delete your existing VM).

When running `make` for the first time, wait for the install to finish
and the VM will reboot and show a login prompt. Leave it running in
your terminal, and open a new secondary terminal session to follow the
next steps.

Switch your local docker context to the new VM:

```
docker context use docker-vm
```

(You can see all the available contexts and switch between them:
`docker context ls`, the script automatically created the `docker-vm`
context for you. The docker context references the name listed in your
`~/.ssh/config` not the IP address.)

Now you should be able to control the remote Docker server using the
local Docker client. Try running this from your local workstation:

```
docker info | head
```

(You should see the name of the VM in the `Context` line at the start of the
output, which indicates that you are talking to the correct docker backend.)

You should be able to run any docker commands now, try:

```
docker run --rm -it -p 80:80 traefik/whoami
```

(This starts a test webserver on port 80 of the VM. The default `EXTRA_PORTS`
setting maps localhost:8000 to docker-vm:80. So you can open your web browser to
to http://localhost:8000 to view the page served by the container.)

The script automatically added an SSH configuration in `~/.ssh/config`, which
facilitates the docker context. You can also use this configuration to SSH
interactively:

```
# You don't normally need to SSH to the VM interactively, but you can:

# ssh docker-vm
```

Shutdown the VM once you've tested things are working:

```
ssh docker-vm shutdown -h now
```

(You should now find that the original `make` command has now exited,
in the first terminal session.)

## Install the systemd service and optionally start it on boot

You can install the systemd service to control the VM and/or startup
on boot, explained in the following steps:

Make sure the VM is shutdown. (`ssh docker-vm shutdown -h now`)

If you want to automatically start the Docker VM on startup, you must
enable ["systemd
lingering"](https://wiki.archlinux.org/title/Systemd/User#Automatic_start-up_of_systemd_user_instances),
which gives you the ability to automatically start services with your
regular user account (not root) at *system* boot (even before logging
in):

```
## Permanently allow your user account to "linger":
sudo loginctl enable-linger ${USER}
```

You also must add your user account to the `kvm` group. (This is only
a requirement if you are staring the VM automatically on boot, *before
logging in*, [otherwise this privilege is handled automatically by
uaccess after you login](https://unix.stackexchange.com/a/599706)):

```
# Add your user to the kvm group:
sudo gpasswd -a ${USER} kvm
```

(Note: I still consider this "unprivileged" access. Adding a user to
the `kvm` group is far safer than adding your user to the `docker`
group.)


Now install the systemd User service that controls the VM:

```
make install
```

This will have created a systemd unit file in
`~/.config/systemd/user/docker-vm.service` (the service is owned by
your unprivileged user account). All of the scripts and all of the VM
data will still reside in the original direcory that you cloned to.

To automatically start the service on boot, you must "enable" it:

```
make enable
```

Once enabled, you should be able to use the docker context. Test
`docker ps`. Test rebooting your host system, and retest `docker ps`
still works.

You can now interact with systemd to control the service (always use
your regular account, not root):

```
# Start:
systemctl --user start docker-vm

# Stop VM with a clean shutdown:
systemctl --user stop docker-vm

# Enable at boot:
systemctl --user enable docker-vm

# Disable at boot:
systemctl --user disable docker-vm

# See status:
systemctl --user status docker-vm

# See logs:
journalctl --user --unit docker-vm
```

You can also use the Makefile targets that are aliases for the above systemctl
commands:

```
make start
make stop
make enable
make disable
make status
make logs
```

(You can also run `make help` to see the descriptions of all of the
commands and/or type `make` and then press your TAB key to show
completions.)

## Firewall

By default, all of the TCP ports that are listed in the Makefile
(including `SSH_PORT` and `EXTRA_PORTS`) are exposed only to your
localhost (`HOSTFWD_HOST='127.0.0.1'`). This prevents other hosts on
your LAN (or from the internet) from accessing your private Docker VM.

This is configurable. If you wish, you can expose your Docker VM
publicly on any or all network interfaces. Just run `make
install-public` to be a fully public (and secure) docker server. You
can further limit access by to a single network interface by setting
`HOSTFWD_HOST=x.x.x.x` to the IP address of the network interface to
allow, or set `HOSTFWD_HOST='*'` to allow all incoming connections
(this is exactly what `make install-public` does for you).

You can install `ufw` to use as a simple firewall to open ports
selectively, and to protect your entire workstation. The default
settings for `ufw` will disable all external inbound connections (and
allow all outbound connections). Simply install and enable ufw:

```
## 'pacman -S ufw' or 'apt install ufw'
sudo ufw enable
```

To open specific ports publicly (eg. `22` and `5432`):

```
sudo ufw allow 22
sudo ufw allow 5432
```

(Note to careful readers: [ufw is not safe to use on the same host operating
system as Docker](https://github.com/chaifeng/ufw-docker#problem), but since
Docker is running in a VM, and ufw is running on the host, this is fine.)

## Uninstall

With one command you can stop the VM, remove all of the VM data, and
uninstall the service.

```
# Run this from the _docker_vm directory:
# This removes ALL the VM data:
make clean
```

Running `make clean` will only remove the data for the VM specified by
the configured `VMNAME` variable, which you can override on the
command line, eg: `VMNAME=my-other-docker-vm make clean`

## Creating more Docker VMs

You can create as many Docker VMs as you want. Just make sure that you
use a different `VMNAME` and use different external port numbers
and/or IP addresses (unique `SSH_PORT` + `EXTRA_PORTS` and/or unique
`HOSTFWD_HOST`).

To create a new VM, you don't have to edit the `Makefile`. You can
just temporarily set the new name, the unique port numbers, and any
other *non-default* settings you need, directly in the terminal:

```
export VMNAME=my-new-docker
export SSH_PORT=2223
export EXTRA_PORTS=8001:80,9443:443
```

Then run `make` and follow all the steps above. Make will use any
temporary environment variable from your current shell, overriding the
variables in the Makefile.

Running `make install` would create a new separate docker service and
context with the given `VMNAME`. These temporary variables are now
saved permanently in the systemd unit file
(`~/.config/systemd/user/${VMNAME}.service`).

## Customize the preseed.cfg file (optional)

The [preseed.cfg](preseed.cfg) is the configuration for the automated
debian-installer. The file is a template file that includes variable
names that are replaced via
[envsubst](https://man.archlinux.org/man/envsubst.1). You can
customize this file however you wish to change how the installer
behaves.

## Credits

The `build_qemu_debian_image.sh` script is a fork from Sylvestre Ledru
(sylvestre) and Hugh Cole-Baker (sigmaris):

 * [opencollab/qemu-debian-install-pxe-preseed](https://github.com/opencollab/qemu-debian-install-pxe-preseed)
 * https://sigmaris.info/blog/2019/04/automating-debian-install-qemu/
([gist](https://gist.github.com/sigmaris/dc1883f782d1ff5d74252bebf852ec50))

I did not find any license for these prior works, but I assume republishing this
here is still in good faith. Thank-you!

I found some great tips for using Qemu in the s.koch blog "Let's Program our own
Cloud Computing Provider":

 * https://blog.stefan-koch.name/2020/12/06/persistent-qemu-instances-systemd
 * https://blog.stefan-koch.name/2020/12/10/qemu-guest-graceful-shutdown-from-python

