# Docker on DigitalOcean

You can use [DigitalOcean](https://www.digitalocean.com/) to host a docker server online.

## Create a droplet on DigitalOcean:

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
 
## Setup your local workstation 

[Install the docker client](https://docs.docker.com/engine/install/) (on Linux this is bundled as "docker engine", which includes both the client and the server, but you do not need to start the server on your workstation, you can run `systemctl mask docker` to prevent the service from starting).

Edit your SSH config file: `~/.ssh/config` (create it if necessary). Add the
following lines, and change it for your domain name that you already created the
DNS record for:

```
Host ssh.d.example.com
    User root
    IdentitiesOnly yes
    ControlMaster auto
    ControlPersist yes
    ControlPath /tmp/ssh-%u-%r@%h:%p
```

(The name `ssh.d.example.com` should work automatically if you setup the
wildcard DNS entry (`*.d.example.com`) created previously. The `ControlMaster`,
`ControlPersist`, `ControlPath` adds SSH connection multi-plexing, and will make
repeated logins/docker commands faster.)

Now test that you can SSH to your droplet:

```
ssh ssh.d.example.com
```

The first time you login to your droplet, you need to confirm the SSH pubkey
fingerprint; press Enter. Once connected, log out: press `Ctrl-D` or type `exit`
and press Enter.

## Setup droplet firewall

Go to the DigitalOcean dashboard, Networking page, click the Firewalls tab.

Create a new firewall: 
 
 * Enter your cluster domain name as the name of the firewall
 * Create the following `Inbound Rules`:
 
    | Type   | Protocol | Port Range | Description                      |
    | ------ | -------- | ---------- | -------------------------------- |
    | SSH    | TCP      |         22 | Host SSH server                  |
    | HTTP   | TCP      |         80 | Traefik HTTP endpoint            |
    | HTTPS  | TCP      |        443 | Traefik HTTPS (TLS) endpoint     |
    | Custom | TCP      |       2222 | Traefik Gitea SSH (TCP) endpoint |
    | Custom | TCP      |       2223 | SFTP container SSH (TCP)         |
    | Custom | TCP      |       8883 | Traefik Mosquitto (TLS) endpoint |
 
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

Logout from the droplet SSH connection, you probably won't ever need to login
again unless there's a problem. You will now use docker exclusively from your
local workstation (laptop).

Setup the docker context to tunnel through your ssh connection (this lets your
workstation docker client control the remote docker server):

```
# From your workstation (replace ssh.d.example.com with your own docker server):
DOCKER_SERVER=ssh.d.example.com
docker context create ${DOCKER_SERVER} --docker "host=ssh://${DOCKER_SERVER}"
docker context use ${DOCKER_SERVER}
```

List all of your docker contexts (your current context is denoted with an
asterisk `*`):

```
docker context ls
```

You can switch between different docker contexts to control multiple Docker
servers (eg. `docker context use my-other-context`).


Test that the connection is working from your local workstation:

```
docker info
```

You should see a lot of information printed, including the droplet hostname. If
so, docker is working.

You can list the running containers, which should be none for a fresh install:

```
docker ps
```

You are now able to use the `docker` and `docker-compose` clients, from your
local workstation, controlling the docker daemon located on your droplet.
