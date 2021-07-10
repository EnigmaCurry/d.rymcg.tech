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

Edit your SSH config file: `~/.ssh/config` (create it if necessary). Add the
following lines, and change it for your domain name that you already created the
DNS record for:

```
Host docker
    Hostname ssh.d.example.com
    User root
```

(`docker` is the local alias name, `ssh.d.example.com` is the actual docker host
domain, where `ssh.` matches the `*` in the wildcard DNS entry created
previously.)

Edit your `~/.bash_profile` and add the `DOCKER_HOST` environment variable:

```
export DOCKER_HOST=ssh://docker
```

Exit your current terminal session and create a new one, or just `source
~/.bash_profile`.

Now test that you can SSH to your droplet:

```
ssh docker
```

The first time you login to your droplet, you need to confirm the SSH pubkey
fingerprint; press Enter.

## Setup droplet ufw firewall

Once logged in, you must configure the `ufw` firewall. You will remove the
default SSH limiting rule, and install the [chaifeng UFW docker
overrides](https://github.com/chaifeng/ufw-docker), which will force docker to
respect your `ufw` firewall rules ([Docker has a giant foot-gun when combined
with ufw](https://github.com/moby/moby/issues/4737) which this fix avoids). Copy
and paste this entire block of code and run:

```
ufw --force reset
echo "Installing UFW docker override : https://github.com/chaifeng/ufw-docker"
cat <<EOF >> /etc/ufw/after.rules
# BEGIN UFW AND DOCKER
*filter
:ufw-user-forward - [0:0]
:ufw-docker-logging-deny - [0:0]
:DOCKER-USER - [0:0]
-A DOCKER-USER -j ufw-user-forward
-A DOCKER-USER -j RETURN -s 10.0.0.0/8
-A DOCKER-USER -j RETURN -s 172.16.0.0/12
-A DOCKER-USER -j RETURN -s 192.168.0.0/16
-A DOCKER-USER -p udp -m udp --sport 53 --dport 1024:65535 -j RETURN
-A DOCKER-USER -j ufw-docker-logging-deny -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 192.168.0.0/16
-A DOCKER-USER -j ufw-docker-logging-deny -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 10.0.0.0/8
-A DOCKER-USER -j ufw-docker-logging-deny -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 172.16.0.0/12
-A DOCKER-USER -j ufw-docker-logging-deny -p udp -m udp --dport 0:32767 -d 192.168.0.0/16
-A DOCKER-USER -j ufw-docker-logging-deny -p udp -m udp --dport 0:32767 -d 10.0.0.0/8
-A DOCKER-USER -j ufw-docker-logging-deny -p udp -m udp --dport 0:32767 -d 172.16.0.0/12
-A DOCKER-USER -j RETURN
-A ufw-docker-logging-deny -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix "[UFW DOCKER BLOCK] "
-A ufw-docker-logging-deny -j DROP
COMMIT
# END UFW AND DOCKER
EOF
ufw allow 22/tcp
ufw route allow proto tcp from any to any port 80
ufw route allow proto tcp from any to any port 443
systemctl enable --now ufw
systemctl restart ufw
ufw --force enable
ufw status
```

If you are using the Gitea container, also open port 2222 for SSH:

```
ufw route allow proto tcp from any to any port 2222
```

If you are using the Mosquitto container, also open port 8883 for MQTT:

```
ufw route allow proto tcp from any to any port 8883
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

## Test docker

Logout from the droplet SSH connection, you probably won't ever need to login
again unless there's a problem. You will now use docker exclusively from your
local workstation (laptop).

On your workstation, [install the docker client](https://docs.docker.com/engine/install/) (on Linux this is bundled as "docker engine", which includes both the client and the server, but you do not need to start the server on your workstation, you can run `systemctl mask docker` to prevent the service from starting).

Test that the `DOCKER_HOST` connection is working from your local workstation:

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
