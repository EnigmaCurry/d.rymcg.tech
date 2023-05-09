# sysbox-systemd

[sysbox](https://github.com/nestybox/sysbox#readme) is a container
runtime that improves process level isolation to a level comparable to
that of Virtual Machines, but without requiring the inefficient
resource hogging of virtualization, nor any hardware accleration
support. sysbox lets you create containers running any
arbitrary/legacy Linux workload. This configuration is setup to run
[systemd](https://wiki.archlinux.org/title/Systemd) as a containerized
PID 1, which is a traditional init system (service manager) for Linux.
With systemd you can run
[Services](https://wiki.archlinux.org/title/Systemd#Examples) and
[Timers](https://wiki.archlinux.org/title/Systemd/Timers) (cron
replacement), or generally any sort of "pet" shell environment that
you can install directly via the container shell terminal.

sysbox is unique in that it is an alternative
[`runc`](https://www.docker.com/blog/runc/), usable by Docker, for
starting unprivileged container processes. Plus, it does not use any
Virtual Machine technology, and yet is flexible enough to be installed
*inside* of any existing virtualized host, regardless of whether or
not that host has nested virtualization hardware support (because it
doesn't need it).

In short, sysbox extends the capabilities of Docker, giving it the
power to run containers for things that normally don't/cannot run as
containers. Beware, running systemd inside of Docker is far outside
the normal container development standard practice, but it can still
be useful/fun in certain contexts.

## Dependencies

### Docker host

Setup a host machine for Docker (engine/server), and prep your
workstation (desktop/laptop) with
[d.rymcg.tech](https://github.com/enigmacurry/d.rymcg.tech).

### sysbox

You must install
[sysbox-runc](https://github.com/nestybox/sysbox#installation) on your
Docker host machine (engine/server). For Debian/Ubuntu, you can
install from the [sysbox package
releases](https://github.com/nestybox/sysbox/releases), or you may
check if your specific distribution has it in their own package
manager (eg. `sysbox-ce` or `sysbox-ce-bin` in the Arch Linux AUR).

Always follow the main sysbox installation instuctions, as this page
may contain outdated information. The follow sections contain
abbreviated sysbox installation procedures and notes.

#### Check your Linux kernel version

It is recommended to install a Linux kernel >5.19 on the host machine
(double check your current kernel version with `uname -a`). Debian
bookworm (Debian 12; current unstable) already comes with kernel 6.1+.
For Debian bullseye (Debian 11; current stable), you should [install
an unstable kernel
(6.1)](https://www.linuxcapable.com/how-to-install-latest-linux-kernel-on-debian-linux/).
Older kernels are supported, but may have more limited feature sets,
and you will see some warnings printed upon install. (May be unable to
access volume-mounts.)

#### Remove existing containers

It is recommended to install sysbox only after a fresh Docker
installation, but if you already have existing docker containers, you
will (unfortunately) need to remove all of them:

```
## Remove all existing containers (but not the volumes):
docker rm $(docker ps -a -q) -f
```

(This will only remove the containers, not the external data volumes,
so you may simply reinstall your container apps again later.)

#### Install sysbox

For Debian/Ubuntu, install these dependencies:

```
apt update
apt install -y jq fuse rsync linux-headers-$(uname -r)
```

Then download and install the sysbox package:

```
## Find the latest release:
### https://github.com/nestybox/sysbox/releases
wget https://downloads.nestybox.com/sysbox/releases/v0.6.1/sysbox-ce_0.6.1-0.linux_amd64.deb
dpkg -i sysbox-ce_0.6.1-0.linux_amd64.deb
```

#### Warnings encountered on kernel 5.10

I saw these warnings on a debian bullseye (stable) with kernel 5.10:

```
Your OS does not support 'idmapped' feature (kernel < 5.12), nor it  provides 'shiftfs' support. In consequence, applications within Sysbox  containers may be unable to access volume-mounts, which will show up as  owned by 'nobody:nogroup' inside the container. Refer to Sysbox  installation documentation for details.

Docker bridge-ip network to configure (172.20.0.1/16) overlaps with existing system subnet. Installation process will skip this docker network setting. Please manually configure docker's 'bip' subnet to avoid connectivity issues.

Docker default-address-pool to configure (172.25.0.0/16) overlaps with existing system subnet. Installation process will skip this docker network setting. Please manually configure docker's 'default-address-pool' subnet to avoid connectivity issues.
```

I suggest you [install kernel
6.1](https://www.linuxcapable.com/how-to-install-latest-linux-kernel-on-debian-linux/)
as in Debian bookworm.

## Install

```
make config
```

(`make config` configures the `default` instance. You may also use
`make instance` to configure a differently named
[instance](https://github.com/EnigmaCurry/d.rymcg.tech#creating-multiple-instances-of-a-service))

You may wish to customize the `.env_{DOCKER_CONTEXT}` file and edit
these variables:

 * `SYSBOX_SYSTEMD_INSTALL_PACKAGES` this is a list of packages to
   install when building the image. Any additional packages that you
   install manually later (ie. ones not in this list) are not saved in
   the image, and are removed when the container is removed.
 * `SYSBOX_SYSTEMD_PUBLIC_PORTS` this is a list port mappings to
   expose to the public network, separted by spaces. (eg. `8000:80
   2222:22` would map two ports: public host port `8000` mapping to
   container port `80`, and public host port `2222` mapping to
   container port `22`.)

```
make install
```

## Access the environment

Start a shell in the current instance:

```
make shell
```

The following directories are mounted to persisten volumes:

 * `/etc`
 * `/home`
 * `/usr/local`

All other files in `/` are ephemeral, and would be removed if the
container is removed (eg. `make uninstall` does this). You may use
`make stop` and this will stop the container, still retaining all the
data in `/` (because the container is only stopped, not deleted); if
used this way, you can use it as a sort of "pet" container where you
can install whatever you want, imperatively. `make destroy` would
remove both the container AND all of the data volumes.

## Create your own systemd services

Inside the shell (`make shell`), you can now create whatever systemd
processes you need. The [Arch Linux systemd
documentation](https://wiki.archlinux.org/title/Systemd) is an
excellent resource, and several service examples can be found in the
[systemd.service man
page](https://man.archlinux.org/man/systemd.service.5#EXAMPLES)

### Example systemd service

As an example, you can install the
[whoami](https://github.com/traefik/whoami) service. You may be
familiar with installing whoami as a docker container, but this time
around you will install it as a systemd service instead.

Install the whomai binary:

```
WHOAMI_ARCH=amd64
WHOAMI_VERSION=v1.9.0

wget https://github.com/traefik/whoami/releases/download/${WHOAMI_VERSION}/whoami_${WHOAMI_VERSION}_linux_${WHOAMI_ARCH}.tar.gz
tar xfv whoami_${WHOAMI_VERSION}_linux_${WHOAMI_ARCH}.tar.gz whoami
install whoami /usr/local/bin
```

Create the service file:

```
cat <<EOF > /etc/systemd/system/whoami.service
[Unit]
Description=whoami
After=network.target

[Service]
User=www-data
ExecStart=/usr/local/bin/whoami
Restart=always

[Install]
WantedBy=multi-user.target
EOF
```

Reload the systemd configuration files:

```
systemctl daemon-reload
```

Enable the service:

```
systemctl enable --now whoami
```

Check that its running:

```
systemctl status whoami
```

(Assuming it works, it should show `Active: active (running)` and for
how long its been running.)

Test the service is working:

```
curl http://localhost
```

This should return the standard `whoami` output, for example:

```
Hostname: sysbox-systemd-linux-stuff
IP: 127.0.0.1
IP: 172.25.18.2
RemoteAddr: 127.0.0.1:39878
GET / HTTP/1.1
Host: localhost
User-Agent: curl/7.74.0
Accept: */*
```

The same result should work from any other machine, over the network,
through Traefik proxy:

```
make open
```

(This will open the secure HTTPS URL of `SYSBOX_SYSTEMD_TRAEFIK_HOST`
in your web browser.)
