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

## Quick start

```
d droplet quick
```

(or choose `Quick start` from the `d droplet` main menu)

Quick start builds a complete Docker server for the current context in
one go. It asks every question up front: droplet name, region, size,
image, SSH key, firewall, reserved IP, backups, domain, subdomain, TLS
certificates, timezone, and whether to install the `whoami` test app.
After you confirm the summary, it runs unattended:

 1. Creates a Web firewall (SSH + HTTP + HTTPS) and a droplet with the
    Docker cloud-init.
 2. Creates `A` records for `SUB.DOMAIN` and `*.SUB.DOMAIN`.
 3. Waits for SSH and for cloud-init to finish installing Docker.
 4. Adds an SSH config entry and a Docker context with the context's
    name, and selects it.
 5. Writes the root config (`ROOT_DOMAIN=SUB.DOMAIN`, `DEFAULT_TIMEZONE`).
 6. Configures and installs Traefik (and acme-dns, with the default TLS
    choice).
 7. Optionally installs `whoami` and waits for it to answer over HTTPS.

The TLS choices are:

 * **Wildcard via self-hosted [acme-dns](acme-dns)** (the default). One
   certificate for `*.SUB.DOMAIN` covers every app you install later,
   and no DigitalOcean token goes on the server. acme-dns runs on the
   droplet as the DNS server for `acme-dns.SUB.DOMAIN`, delegated to it
   by an `NS` record, and Traefik's acme.sh answers the DNS-01
   challenges through it. Quick start creates the `NS`, `A` and
   `_acme-challenge` `CNAME` records with your local doctl, and opens
   port 53 (TCP and UDP) in the firewall. acme-dns always gets a
   *production* certificate for its own API, and Let's Encrypt issues
   at most 5 per week for the same name, so avoid destroying and
   rebuilding the same subdomain repeatedly.
 * **Wildcard via the DigitalOcean DNS API**. The same wildcard
   certificate with fewer moving parts, but Traefik needs a
   DigitalOcean API token, which is stored on the server. Give it a
   separate token with custom scopes (`domain:read`, `domain:update`)
   rather than reusing your doctl token.
 * **One certificate per app name** with the TLS-ALPN-01 challenge. No
   token on the server, but each new app's name must be added to
   Traefik's certificate list (`d make traefik config`), followed by a
   Traefik reinstall.
 * **None**: Traefik's self-signed default certificate only.

Inside [drt](WORKSTATION_CONTAINER.md), start a session for a context
that has no Docker host yet (`drt --init foo`, answer *no* to the SSH
question, then `drt foo`). Run `d droplet quick` there, and answer `Y`
to *Save changes* when you exit: the next `drt foo` connects straight
to the droplet.

If a run fails partway, run it again and give the same droplet name:
it offers to resume on the existing droplet, and skips the droplet
questions.

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
