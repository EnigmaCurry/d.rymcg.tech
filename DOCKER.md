# Docker

This guide shows you how to install a Docker server and setup the firewall.

## Requirements

 * You will need an existing Linux server or VM (amd64 or aarch64)
   running Debian (recommended), Raspbian, Ubuntu, Fedora, or RHEL. It
   should be a fresh install, with no other services running yet
   (except for basic system services like SSH or collectd).

   * If you don't already have a Linux server, you can install one any of these ways:

     * Follow the [Debian GNU/Linux Installation
       Guide](https://www.debian.org/releases/stable/amd64/) on any PC
       to run Docker natively on AMD64.
     * [RASPBERRY_PI.md](RASPBERRY_PI.md) - Install Raspberry Pi OS to
       run Docker natively on Aarch64.
     * [PROXMOX.md](PROXMOX.md) - Install Proxmox (PVE) on a PC to to
       run Docker in a virtual machine on AMD64.
     * [DIGITALOCEAN.md](DIGITALOCEAN.md) - Create a DigitalOcean
       droplet to run Docker in the cloud.
     * [AWS.md](AWS.md) - Create an AWS EC2 instance to run Docker in
       the cloud.

 * You should already have your workstation setup:

   * [WORKSTATION_LINUX.md](WORKSTATION_LINUX.md) - Setup your workstation on Linux.
   * [WORKSTATION_WSL.md](WORKSTATION_WSL.md) - Setup your workstation on Windows (WSL)
 
## Setup SSH and Docker context

From your workstation, run:

```
d context new
```

This will confirm that you want to create a new context:

```
> This command can help create a new SSH config and Docker context. Proceed? Yes
```

It will ask if you want to create the SSH host config, or to use an
existing one from `~/.ssh/config` (this example shows to create a new
entry after pressing the down arrow key):

```
? You must specify the SSH config entry to use  
> I want to make a new SSH host entry in ~/.ssh/config
  I already have an SSH host entry in ~/.ssh/config that I want to use
```

Enter the context name. This should be a short recognizable name (no
spaces). E.g., `widgets`:

```
> Enter the new SSH context name (short host name) : widgets
```

Enter the domain name or IP address of your Docker server:

```
> Enter the fully qualified SSH Host DNS name or IP address : 123.123.123.123
```

Confirm that you want to save the config:

```
> Do you want to append this config to ~/.ssh/config? Yes
```

Switch context to this context at any time:

```
d context
```

Choose the context you want to switch to:

```
? Select the Docker context to use  
  d-test
  insulon
> widgets
[↑↓ to move, enter to select, type to filter, ESC to cancel]
```

With the correct context selected, the `d.rymcg.tech` and `d` alias
will now affect that contexts remote Docker server.

## Install Docker

Make sure the correct context is selected:

```
d context
```

To install Docker, run this command:

```
d install-docker
```

The first time you are connecting, you need to confirm the SSH host
key (type `yes`):

```
The authenticity of host '1.2.3.4 (1.2.3.4)' can't be established.
ED25519 key fingerprint is SHA256:MJXpZH1KbzwJqvoR6gpMCR/p1CKocQwqgd7cDncpxHo.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
```

Watch the output for messages of success or failure. After successful
installation, it should show:

```
docker-test systemd[1]: Started docker.service - Docker Application Container Engine.
```

If you are running an unsupported Linux distribution, you should
consult your own vendor documentation (e.g., Docker on [Arch
Linux](https://wiki.archlinux.org/title/Docker)) or the upstream
[Docker Engine](https://docs.docker.com/engine/install/#server)
documentation.

## Configure context 

```
d config
```

```
> This will make a configuration for the current docker context (dtest2). Proceed? Yes
ROOT_DOMAIN: Enter the root domain for this context (eg. d.example.com)
: d.example.com

> Is this server behind another trusted proxy using the proxy protocol? No

> Do you want to save cleartext passwords in passwords.json by default? No
```

This will write the `.env_{CONTEXT}` file in the root of the
d.rymcg.tech source directory, containing the the global environment
files per context.
## Configure Docker bridge networks (optional)

By default, Docker will only reserve enough IP addresses for a total
of 30 user-defined networks. This means that, by default, you can only
deploy up to 30 projects per docker server.

If you plan to install more than that, or you want to explicitly
change the IP address range, there is a workstation command to do this
automatically:

```
## Example: 172.17.0.0/16 24     = 256 /24 subnets
##                               = 172.17.0.0 - 172.17.255.255
##                               = 65,536 addresses

d docker-default-address-pool 172.17.0.0/16 24
```

This will reconfigure the server's `/etc/docker/daemon.json` and
restart Docker.

## Firewall

This system does not include a network firewall of its own. You are
expected to provide a firewall in your hosting provider (or VM host)
networking environment. (Note: `ufw` is NOT recommended for use with
Docker, nor is any other firewall that is directly located on the same
host machine as Docker. You should prefer an external dedicated
network firewall [ie. your cloud provider, or VM host]. If you have no
other option but to run the firewall on the same machine, check out
[chaifeng/ufw-docker](https://github.com/chaifeng/ufw-docker#solving-ufw-and-docker-issues)
for a partial fix.)

With only a few exceptions, all network traffic flows through one of
several Traefik entrypoints, listed in the [static configuration
template](traefik/config/traefik.yml) (`traefik.yml`) in the
`entryPoints` section.

Each entrypoint has an associated environment variable to turn it on
or off. See the [Traefik](traefik) configuration for more details.

Depending on which services you actually install, and how they are
configured, you may need to open these ports in your firewall:

| Type       | Protocol | Port Range | Description                                               |
|------------|----------|------------|-----------------------------------------------------------|
| SSH        | TCP      | 22         | Host SSH server (direct-map)                              |
| HTTP       | TCP      | 80         | Traefik HTTP entrypoint (web; redirects to websecure)     |
| HTTP+TLS   | TCP      | 443        | Traefik HTTPS entrypoint (websecure)                      |
| TCP socket | TCP      | 1704       | Traefik Snapcast (audio) entrypoint                       |
| TCP socket | TCP      | 1705       | Traefik Snapcast (control) entrypoint                     |
| RTMP(s)    | TCP      | 1935       | Traefik RTMP (real time message protocol) entrypoint      |
| SSH        | TCP      | 2222       | Traefik Forgejo SSH (TCP) entrypoint                      |
| SSH        | TCP      | 2223       | SFTP container SSH (TCP) (direct-map)                     |
| TLS        | TCP      | 5432       | PostgreSQL mTLS DBaaS (direct-map)                        |
| TCP+TLS    | TCP      | 6380       | Traefik Redis in-memory database entrypoint               |
| TCP socket | TCP      | 6600       | Traefik Mopidy (MPD) entrypoint                           |
| HTTP       | TCP      | 8000       | Traefik HTTP entrypoint (web_plain; explicitly non-https) |
| TLS        | TCP      | 8883       | Mosquitto MQTT (direct-map)                               |
| WebRTC     | UDP      | 10000      | Jitsi Meet video bridge (direct-map)                      |
| VPN        | UDP      | 51820      | Wireguard (Traefik VPN)  (direct-map)                     |

The ports that are listed as `(direct-map)` are not connected to
Traefik, but are directly exposed (public) to the docker host network.

For a minimal installation, you only need to open ports 22 and 443.
This would enable all of the web-based applications to work, except
for the ones that need an additional port, as listed above.

See [DIGITALOCEAN.md](DIGITALOCEAN.md) for an example of setting the
DigitalOcean firewall service.

Later, you may wish to audit the open published ports of the apps
you've installed: 

```
d show-ports
```
## Install apps

Go forth, and install any apps from [README.md](README.md) and/or
[TOUR.md](TOUR.md).
