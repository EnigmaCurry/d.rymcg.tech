# sysbox-systemd

[sysbox](https://github.com/nestybox/sysbox#readme) is a container
runtime that lets you create arbitrary Linux workloads as containers,
with Docker. This configuration is setup to run systemd, in order to
run any arbitrary/legacy Linux service, or to use systemd Timers as a
cron replacement, or generally any sort of "pet" shell environment.
sysbox is unique in that it is an alternative `runc`, usable by
Docker, and it does not use a virtual machine, and is flexible enough
to be installed *inside* of any virtualized host, regardless of
whether or not that host has nested virtualization (hardware) support.
In short, sysbox extends the capability of Docker, to run any sort of
process that would *normally* require a Virtual Machine (or bare metal
install), but inside of a small unprivileged container instead.

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

