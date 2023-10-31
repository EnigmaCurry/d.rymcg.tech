# d.rymcg.tech installation guide

This is an opinionated installation guide for
[d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech/tree/master#drymcgtech)
explained in an orderly manner and with fewer distractions, and yet
demonstrating the broad capabilities of many of its systems. It should
be used as a supplement to the main project [README.md](README.md).

The goal of this guide is to create a public Docker server on a
DigitalOcean droplet, entirely managed with the `d.rymcg.tech` tools
installed on your personal workstation (a Raspberry Pi in this
example).

By following this guide, you will complete all of the following steps,
in order.

## Setup a new Raspberry Pi workstation

> [!NOTE]
> If you read between the lines, you can set this up on any
> Linux computer. For proper hygiene/separation on a per-project
> basis, it is recommended to use a clean OS install (possibly on a
> virtual machine), or simply creating a dedicated/secure user account
> on your existing machine. A Raspberry Pi, separate from your main
> computer, is excellent for this role.

Follow the guide in [RASPBERRY_PI.md](RASPBERRY_PI.md) for installing
Raspbian Lite and Docker onto your Raspberry Pi. For the purposes of
this guide, the raspberry pi does not need to run the Docker daemon.
After installation, you can disable the Docker service on the pi:

```
## Run this on the pi to disable Docker daemon:
sudo systemctl mask --now docker
```

## Create a DigitalOcean account

> [!NOTE]
> If you read between the lines you can set this up on any
> dedicated Linux server or VPS provider. You should pick one that
> offers an external firewall service. DigitalOcean is excellent for
> demonstration purposes because it is quickly created and quickly
> destroyed, and is considerably inexpensive for quick demos.
> DigitalOcean also offers its own firewall service. `d.rymcg.tech` is
> "cloud agnostic", the platform just needs to have a Linux kernel, be
> able to run Docker, and have an SSH server to access it remotely.

## Purchase and register an Internet domain name

> [!NOTE]
> You may use any domain registrar you want, I recommend
> [gandi.net](https://gandi.net)

## Transfer your domain name to use DigitalOcean DNS

> [!NOTE]
> DigitalOcean DNS is used for documentation purposes,
> any DNS provider can do the same thing.

On your domain registrar provider's interface (eg. gandi.net),
configure your domain name DNS server setting. Set it to use these
DigitalOcean DNS servers:

 * `ns1.digitalocean.com`
 * `ns2.digitalocean.com`
 * `ns3.digitalocean.com`

## Create a Docker server on DigitalOcean

 * Create a DigitalOcean account and login to
   [cloud.digitalocean.com](https://cloud.digitalocean.com)
 * Click `Create`, then `Droplet`
 * Navigate to the `Marketplace` tab, then choose the `Docker XX.X on Ubuntu` image.
 * Choose whatever droplet size you need (at least 2GB ram recommended for most installs).
 * Optional: Add a block storage device, in order to store your Docker volumes.
   (This is useful to store data separate from the droplet lifecycle. If your
   basic droplet size is sufficient, and you perform regular backups, this might
   not be needed.)
 * Choose datacenter/region. Note: block storage and floating IPs are bound to
   the datacenter you choose.
 * Add your SSH key.
 * Choose a hostname.
 * Click `Create Droplet`
 * Optional: Create a Floating IP address. This is useful if you need to
   re-create your droplet, but do not want to update the DNS. Navigate to the
   droplet page, find `Floating IP` and click `Enable Now`.
 * Add a DNS record for the Floating IP address (or the droplet public IP
   address if you opted not to use a Floating IP.) Use a wildcard name like
   `*.d.example.com`, so that any subdomain in place of `*` will resolve to your
   droplet. You may use your own DNS host or you may use DigitalOcean DNS (go to
   `Networking` / `Domains`, add or find your domain, create record, enter name
   as `*.d.example.com`, and direct to your floating or droplet IP.)

## Install `d.rymcg.tech` tools on your workstation

 * Create remote docker context on your workstation
 * Configure `d.rymcg.tech` for your docker context

## Configure Traefik using your own domain name

 * Create a TLS certificate and sign it with Let's Encrypt.

## Install the Whoami service to test web service connectivity.
## Install Gitea and traefik-forward-auth for strong User authentication/authorization.

 * Configure Traefik `make sentry` to create users and groups to add
   OAuth to any app using your Gitea user accounts.

## Install Homepage to use as a dashboard
## Install minio S3 storage server

 * Install rclone-browser to upload files to your S3 server
 * Install s3-proxy to present files publicly in the web browser

## Install SFTP volume manager

 * Install thttpd server to serve files publicly in the web browser

