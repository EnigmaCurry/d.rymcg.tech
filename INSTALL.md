# d.rymcg.tech installation guide

This is an opinionated installation guide for
[d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech/tree/master#drymcgtech)
explained in an orderly manner and with fewer distractions, and yet
demonstrating the broad capabilities of many of ts systems. It should
be used as a supplement to the main project [README.md](README.md), as
well as to the individual project READMEs. Many concepts in this guide
will be glossed over, and fewer options will be presented. If you are
just starting with this guide, make sure to go back and read the full
READMEs eventually to fill in the gaps.

The goal of this guide is to create a public Docker server on a
DigitalOcean droplet, entirely managed with the `d.rymcg.tech` tools
installed on your personal workstation (a Raspberry Pi in this
example).

By following this guide, you will complete all of the following goals,
in order:

 * Purchase and register an Internet domain name
 * Create a DigitalOcean account

<aside class="notice"> If you read between the lines you can set this
up on any dedicated Linux server or VPS provider. You should pick one
that offers an external firewall service (d.rymcg.tech doesn't provide
any firewall, and you shouldn't use `ufw` with docker, or any other
firewall on the same host as docker.) DigitalOcean is excellent for
demonstration purposes because it is quickly created and quickly
destroyed, and is considerably inexpensive for quick demos.
DigitalOcean also offers its own firewall service. `d.rymcg.tech` is
"cloud agnostic", the platform just needs to have a Linux kernel, be
able to run Docker, and have an SSH server to access it remotely.
</aside>

 * Transfer your domain name to use DigitalOcean DNS

<aside class="notice">DigitalOcean DNS is used for documentation
purposes, any DNS provider can do the same thing.</aside>

 * Setup a new Raspberry Pi workstation

<aside class="notice">If you read between the lines, you can set this
up on any Linux computer. For proper hygiene/separation on a
per-project basis, it is recommended to use a clean OS install
(possibly on a virtual machine), or simply creating a dedicated/secure
user account on your existing machine. A Raspberry Pi, separate from
your main computer, is excellent for this role.</aside>

 * Create a Docker server on DigitalOcean
 * Install `d.rymcg.tech` tools on your workstation

   * Create remote docker context on your workstation
   * Configure `d.rymcg.tech` for your docker context

 * Configure Traefik using your own domain name

   * Create a TLS certificate and sign it with Let's Encrypt.

 * Install the Whoami service to test web service connectivity.
 * Install Gitea and traefik-forward-auth for strong User authentication/authorization.

   * Configure Traefik `make sentry` to create users and groups to add
     OAuth to any app using your Gitea user accounts.

 * Install Homepage to use as a dashboard
 * Install minio S3 storage server

   * Install rclone-browser to upload files to your S3 server
   * Install s3-proxy to present files publicly in the web browser

 * Install SFTP volume manager

   * Install thttpd server to serve files publicly in the web browser


## Buy a domain name
## Setup DNS on DigitalOcean
## Create your workstation
## Create the Docker droplet on DigitalOcean
