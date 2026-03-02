# Docker on DigitalOcean

You can use [DigitalOcean](https://www.digitalocean.com/) to host a Docker
server online. The `d.rymcg.tech` tool includes an interactive manager for
DigitalOcean resources called **gumdrop**, accessed via the `d droplet` (or `d gumdrop`)
command.

Note: this doc leaves out a lot of important bits. Read the main
[d.rymcg.tech README](README.md) to fill in those gaps!

## Prerequisites

 * A DigitalOcean account with a
   [personal access token](https://docs.digitalocean.com/reference/api/create-personal-access-token/).
 * [doctl](https://docs.digitalocean.com/reference/doctl/how-to/install/)
   installed and available on your PATH.

The first time you run `d droplet`, you will be prompted to add your
DigitalOcean account (name and API token). You can manage multiple
accounts from the Accounts menu.

## Create a droplet

```
d droplet
```

Choose **Droplets → Create new droplet** and follow the interactive
wizard. You will be asked to choose:

 * A name for the droplet.
 * A region, size, and image (Debian is the default).
 * SSH key(s) to install.
 * Optional tags.
 * Optional block storage volume (useful if you plan to exceed the
   droplet's root disk; the volume stores `/var/lib/docker`).
 * Optional firewall to apply (defaults to blocking all incoming).
 * Optional backups (daily or weekly snapshots).
 * A user-data (cloud-init) script — **select the Docker option for
   your image** (e.g. "Docker (debian based)"). This installs Docker
   and automatically mounts any attached block storage volume as
   `/var/lib/docker`. The default is "No", so be sure to change it.

Once the droplet is created, you can SSH into it directly from the
menu (**Droplets → SSH into droplet**), or add it to your local SSH
config (**Droplets → Add to local SSH config**).

## Setup firewall

From the main menu choose **Firewalls → Create new firewall**. A
typical web-hosting firewall needs these inbound rules:

| Type | Protocol | Port Range | Description                        |
| ---- | -------- | ---------- | ---------------------------------- |
| TCP  | TCP      |         22 | Host SSH server                    |
| TCP  | TCP      |         80 | Traefik HTTP endpoint              |
| TCP  | TCP      |        443 | Traefik HTTPS (TLS) endpoint       |
| TCP  | TCP      |       2222 | Traefik Forgejo SSH (TCP) endpoint |
| TCP  | TCP      |       2223 | SFTP container SSH (TCP)           |
| TCP  | TCP      |       8883 | Traefik Mosquitto (TLS) endpoint   |

Add whatever other ports you need, then assign the firewall to your
droplet.

Then disable the host firewall (the DigitalOcean firewall operates
at the network level). From the main menu choose **Firewalls →
Disable ufw on droplet**, select your droplet, and confirm.

## Setup DNS

From the main menu choose **Domains → DNS records**, select your
domain, then **Create record**. You will typically want a wildcard A record pointing to
your droplet's IP address:

 * Type: `A`
 * Name: `*.d` (or `*` to dedicate the whole domain)
 * Data: your droplet's public IP address

This lets any subdomain (e.g. `app.d.example.com`) resolve to your
server.

## Block storage for Docker volumes

If you attach a block storage volume during droplet creation, the
built-in Docker user-data scripts will automatically detect it and
remount the largest volume as `/var/lib/docker` during first boot.
No manual steps are needed.

If you add a volume to an existing droplet, you can remount it from
the main menu: **Volumes → Mount volume as /var/lib/docker**.

Block storage volumes can also be managed from the **Volumes** menu
in `d droplet`.

## Other resources

The `d droplet` main menu also provides management for:

 * **SSH keys** — add, list, and delete SSH keys on your account.
 * **Volumes** — create, attach, detach, resize, and snapshot volumes.
 * **NFS** — create and manage NFS shares backed by block storage.
 * **Reserved IPs** — allocate and assign static IP addresses.
 * **Domains** — add and delete domains, and manage DNS records
   (A, AAAA, CNAME, MX, TXT, NS, SRV, CAA).
 * **Snapshots** — create and restore droplet snapshots.
 * **Backups** — manage and convert droplet backups.
 * **Accounts** — switch between multiple DigitalOcean accounts.

## Removing an account

When you no longer need a DigitalOcean account configured in
gumdrop, go to **Accounts → Remove account** to delete its stored
credentials. This only removes the local configuration — it does not
affect your DigitalOcean account itself.

## Setup Docker context and test Docker connection

Follow the rest of the steps in [DOCKER.md](DOCKER.md).
