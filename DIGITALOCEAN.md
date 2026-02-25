# Docker on DigitalOcean

You can use [DigitalOcean](https://www.digitalocean.com/) to host a Docker
server online. The `d.rymcg.tech` tool includes an interactive manager for
DigitalOcean resources called **gumdrop**, accessed via the `d droplet`
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
 * Optional firewall to apply.
 * Optional backups (daily or weekly snapshots).
 * A user-data script (the default installs Docker on Debian).

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
at the network level). From the main menu choose **Tasks → Disable
ufw**, select your droplet, and confirm.

## Setup DNS

From the main menu choose **Domains → DNS records**, select your
domain, then **Create record**. You will typically want a wildcard A record pointing to
your droplet's IP address:

 * Type: `A`
 * Name: `*.d` (or `*` to dedicate the whole domain)
 * Data: your droplet's public IP address

This lets any subdomain (e.g. `app.d.example.com`) resolve to your
server.

## Setup block storage for Docker volumes

If you attached a block storage volume during droplet creation, it is
formatted and mounted automatically under `/mnt/`. To remount it as
`/var/lib/docker` so Docker uses the external storage, choose
**Tasks → Mount volume as /var/lib/docker** from the main menu,
select your droplet, and confirm. The task will automatically find the
volume, stop Docker, move the data, update the systemd mount unit,
and restart Docker.

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
 * **Tasks** — run common setup tasks on droplets (disable ufw,
   mount volume as /var/lib/docker).

## Removing an account

When you no longer need a DigitalOcean account configured in
gumdrop, go to **Accounts → Remove account** to delete its stored
credentials. This only removes the local configuration — it does not
affect your DigitalOcean account itself.

## Setup Docker context and test Docker connection

Follow the rest of the steps in [DOCKER.md](DOCKER.md).
