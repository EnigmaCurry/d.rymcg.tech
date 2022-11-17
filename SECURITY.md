# Docker Security

This document outlines some general guidelines for running a secure
Docker server, and specific notes regarding the containers hosted by
[d.rymcg.tech](https://github.com/enigmacurry/d.rymcg.tech). This
guide is not comprehensive. The standard disclaimer from the
[LICENSE](LICENSE.txt) is worth repeating:

```
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

You should start by reading the official [Docker
security](https://docs.docker.com/engine/security/) guide.

## Server Setup

### Server selection

You can install Docker on pretty much any Linux server, but some hosts
are better than others.

In addition to the standard criteria of location, cost, performance,
etc, you should consider if you host has the following features:

 * Hosted Firewall
   * A Docker server will manage the iptables of the entire host
     machine, and this can have unintended consequences when it comes
     to protecting the open ports of the Docker server.
   * You should not use a firewall manager like `ufw` or `firewalld`
     on the same host with Docker. These tools will deceive you and
     Docker may publish ports you thought were blocked.
   * It is best to think of iptables on the Docker server as a routing
     table, and not a security device.
   * Instead of relying on the local server firewall, you should use
     the external firewall that is provided by your hosting provider.
     Usually this is a web dashboard to select the incoming ports and
     default rules.
   * A basic firewall ruleset should allow:
     * Port 22 for admin SSH access
     * Port 80 for HTTP redirection to HTTPS
     * Port 443 for all web (HTTPS) traffic
     * Deny all other ports, unless you choose to open something else.

 * Nested Virtualization
   * Although not necessary for a normal Docker installation, you may
     want to run a virtual machine like KVM or microVMs in containers
     with [firecracker](https://firecracker-microvm.github.io/). If
     you have a VPS that is already virtualized, you need to have the
     Nested Virtualization kernel feature to run VMs inside of VMs.

```
# Check if nested virtualization supported:
## Intel:
cat /sys/module/kvm_intel/parameters/ne
## AMD:
cat /sys/module/kvm_amd/parameters/nested
```

  * Nested virtualization can be useful for creating [multiple Docker
    VMs](_docker_vm) inside of one VPS.
    * This could be useful on VPS that don't have an external
      firewall, you can run `ufw` on the host VPS, and then run Docker
      inside of a nested KVM virtual machine.

 * Size
   * Don't get a server that is too big for your needs. Get a VPS that
     is sized exactly for one instance of Docker, where you can choose
     exactly how much RAM and disk you need. Otherwise you may be
     tempted to install other things on your server besides Docker and
     this complicates the security of the server.

### Harden SSH

 * Configure `/etc/ssh/sshd_config` or add files in
   `/etc/ssh/sshd_config.d` and ensure the following options are
   set:
   * `PermitRootLogin prohibit-password`
   * `PubkeyAuthentication yes`
   * `PasswordAuthentication no`
 * Consider disabling host keys you do not need. 
   * Prefer using `rsa` or `ed25519` keys.
   * Disable older `dsa` and `ecdsa` key types.

### Installing Docker

 * Install Docker on
   [Debian](https://docs.docker.com/engine/install/debian/) or
   [Ubuntu](https://docs.docker.com/engine/install/ubuntu/). 
   * Follow the exact instructions from docker.com, do not install
     Docker from your regular package manager repository, but use
     docker.com package repository instead.
   * If you are proficient with a different distro, go ahead.

### What about User Namespaces or Rootless mode?

Docker has two non-default settings that could improve security of
your containers, by mapping non-existant host UID ranges to the
container space. These two settings are [User Namespace mode]() and a
[Rootless mode](https://docs.docker.com/engine/security/rootless/).

However, the current [Traefik](traefik) configuration is setup to use
the host network, which is incompatible with such settings, so they
will not be considered here.

## Docker container privileges

Docker Engine runs as root (in the default configuration). By default,
all containers run as root too. Root inside the container is the same
UID as root outside the container (UID=0). Docker tries to do some
minimal sandboxing, but the fact remains that if you run a docker
container without any consideration for limiting the default
privileges, your attack surface is far larger than necessary.

When creating Docker containers, you should limit the privileges and
[capabilities](https://man.archlinux.org/man/capabilities.7) granted
to it.

### Run containers as a non-root user

In a `Dockerfile` you can add a unprivileged user to use as the default user:

```
FROM alpine:3
ARG USER_UID=54321
RUN adduser foo -D -u ${USER_UID}
USER foo
```

Or you can run an image with an alternate UID:

```
# Example docker command:
docker run --rm -it --user 1234:1234 alpine:3 id -u
```

```
# Example docker-compose.yaml
version: "3.9"

services:
  thing:
    image: alpine:3
    user: ${USER_UID:-54321}:${USER_GID:-54321}
```

### Drop system capabilities

By default, containers are given only a limited set of [default
capabilities](https://github.com/moby/moby/blob/master/oci/caps/defaults.go#L6-L19)
(See [all Linux capabilities
here](https://man.archlinux.org/man/capabilities.7)) This means that
`root` inside the container is not quite as powerful as `root` outside
the container, but still has more privileges than necessary.

You can tell a container to start with a different list of privileges
than the default via the `--cap-drop`, `--cap-add`, and `--security-opt`
flags.

Here is an example that drops ALL privileges:

```
version: "3.9"
  thing:
    .....
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
```

`cap_drop: ['ALL']` tells the container to drop all privileges, even
the default ones that Docker normally gives. the
`no-new-privileges:true` flag disallows acquiring any privileges not
granted at the start (for instance a binary can have `setcap` enable a
root capability for a non-root user, for that program only, similar in
concept to `setuid` but for more fine-grained permission control.)

Unless your container works entirely without root access, this list is
likely too restrictive. You will need to use `cap_add` to add some of
the capabilites back. A good strategy is to drop `ALL` capabilites,
and then add all of them back, explicity. Then you can comment out the
capabilites you don't need, testing them by process of elimination,
whether container behaves properly without them:

NOTE: the following example, with all capabilites added, is
essentially the same as running your container with `privileged:
true`:

```
version: "3.9"
  thing:
    .....
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      ### ALL capabilities back explicitly:
      ## Try to comment most of these out and see how your container behaves
      - SETGID
      - SETUID
      - CHOWN
      - DAC_OVERRIDE
      - SYS_CHROOT
      - AUDIT_WRITE
      - FOWNER
      - AUDIT_CONTROL
      - AUDIT_READ
      - BLOCK_SUSPEND
      - DAC_READ_SEARCH
      - FSETID
      - IPC_LOCK
      - IPC_OWNER
      - KILL
      - LEASE
      - LINUX_IMMUTABLE
      - MAC_ADMIN
      - MAC_OVERRIDE
      - MKNOD
      - NET_ADMIN
      - NET_BIND_SERVICE
      - NET_BROADCAST
      - NET_RAW
      - SETFCAP
      - SETPCAP
      - SYS_ADMIN
      - SYS_BOOT
      - SYSLOG
      - SYS_MODULE
      - SYS_NICE
      - SYS_PACCT
      - SYS_PTRACE
      - SYS_RAWIO
      - SYS_RESOURCE
      - SYS_TIME
      - SYS_TTY_CONFIG
      - WAKE_ALARM
```

You should never run a container as `--privileged` or `privileged:
true`. Instead, you should figure out the exact capabilities it needs
by process of elimination.
