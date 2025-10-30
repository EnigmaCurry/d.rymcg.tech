# Docker on DigitalOcean

You can use [DigitalOcean](https://www.digitalocean.com/) to host a docker server online.

Note: this doc leaves out a lot of important bits. Read the main
[d.rymcg.tech README](README.md) to fill in those gaps!

## Create a droplet on DigitalOcean:

 * Create a DigitalOcean account and login to
   [cloud.digitalocean.com](https://cloud.digitalocean.com)
 * Click `Create`, then `Droplets`.
 * Choose a Region to install to.
 * Choose the `Debian` image.
 * Choose whatever droplet size you need. I regularly use a 512MB+zram
   droplet and use it for all development purposes).
 * Optional: Enable backup (daily or weekly snapshots).
 * Optional: Add a block storage device if you plan to exceed the disk
   storage of the droplet. This volume is used to store all of the
   container volumes (`/var/lib/docker`). Choose `Automatically Format
   & Mount`. Important: external volumes are *not* included in droplet
   backups, but you may perform manual volume snapshots yourself.
 * Add your workstation SSH key.
 * Choose a hostname.
 * Click `Create Droplet`.
 * Once the droplet is created, find the public IP address (or
   floating IP). Add a wildcard DNS record like `*.d.example.com` (or
   `*.example.com` if you want to dedicate your whole domain), so that
   any subdomain in place of `*` will resolve to your droplet. You may
   use your own DNS host or you may use DigitalOcean DNS (go to
   `Networking` / `Domains`, add or find your domain, create an `A`
   record, enter name as `*.d.example.com`, and direct to your
   droplet's IP address.)
 
## Setup droplet firewall

Go to the DigitalOcean dashboard, Networking page, click the Firewalls tab.

Create a new firewall: 
 
 * Enter any name you want for the firewall (eg. use the  domain or server role name to help identify it).
 * Create the following `Inbound Rules`:
 
    | Type   | Protocol | Port Range | Description                        |
    | ------ | -------- | ---------- | ---------------------------------- |
    | SSH    | TCP      |         22 | Host SSH server                    |
    | HTTP   | TCP      |         80 | Traefik HTTP endpoint              |
    | HTTPS  | TCP      |        443 | Traefik HTTPS (TLS) endpoint       |
    | Custom | TCP      |       2222 | Traefik Forgejo SSH (TCP) endpoint |
    | Custom | TCP      |       2223 | SFTP container SSH (TCP)           |
    | Custom | TCP      |       8883 | Traefik Mosquitto (TLS) endpoint   |
 
 * (and any other ports you need.)
 * Search for the Droplet you create and apply the firewall to it.
 * You can verify the firewall is applied, by going to the Droplet page and
   going to the Droplet Network settings page.
 
Login to the droplet shell terminal, and disable the ufw firewall:

```
ufw disable
systemctl mask ufw
```
 
## Setup droplet volumes on block storage

Normally, Docker stores all data (including volumes) at `/var/lib/docker` which
is on the root partition of the droplet storage. In order to use external block
storage, you must move the existing data to the block storage device and
re-mount the block storage to this location.

By default, DigitalOcean formats and mounts your block storage device to a
location with a variable name, for instance: `/mnt/volume_nyc1_01` (the name
will depend on the datacenter, region, and the number of block storage devices
that you've created.) You can find where this mount location is by running `df -h`
(double check the storage size column).

Shutdown docker:

```
systemctl stop docker
```

Move the data to the block storage device, ensuring to use the actual mount
location specific to your droplet:

```
mv /var/lib/docker/* /mnt/volume_nyc1_01/
```

Unmount the block storage device:

```
umount /mnt/volume_nyc1_01
```

Edit the systemd unit file responsible for mounting the block storage device
`/etc/systemd/system/mnt-volume_nyc1_01.mount`. Change the line
`Where=/mnt/volume_nyc1_01` to `Where=/var/lib/docker`.


Rename the file in order to match the new mount location:

```
mv /etc/systemd/system/mnt-volume_nyc1_01.mount /etc/systemd/system/var-lib-docker.mount
```

Reload the systemd configuration:

```
systemctl daemon-reload
```

Enable and start the new service:

```
systemctl enable --now var-lib-docker.mount
```

Verify the mount is in the new location (`/var/lib/docker`) by running `df -h`
and `ls /var/lib/docker` (it should now contain all of the original directories
that docker created, including the `volumes` directory).

Restart docker:

```
systemctl start docker
```

Reboot the droplet (`reboot`) and double check that the volume is automatically
mounted on startup (`df -h`)

## Setup Docker context and test Docker connection

Follow the rest of the steps in [DOCKER.md](DOCKER.md).
