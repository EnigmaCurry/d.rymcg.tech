# Docker on Raspberry Pi

## Install Rasbian

 * Download the latest [Raspberry Pi OS Lite (64-bit) image zip file](https://downloads.raspberrypi.org/raspios_lite_arm64/images/?C=M;O=D).
 * For example as of 2022-01-28 that would be:

```
wget https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2022-01-28/2022-01-28-raspios-bullseye-arm64-lite.zip
```

 * Insert your sd-card, and check what the root device name is called, with
   `lsblk` based upon device size. In my case it is called `mmcblk0`.
 * Write the zip file to the sdcard device (make sure to replace `/dev/mmcblk0` with your device name):

```
unzip -p 2022-01-28-raspios-bullseye-arm64-lite.zip | \
   sudo dd of=/dev/mmcblk0 bs=4M conv=fsync status=progress
```
 * Once the image is finished writing, remove the sd-card device, and put it
   back in.
 * Mount the first partition of the sd-card (eg `mount /dev/mmcblk0p1 /mnt`)
 * Create a file in the root of the sd-card called `ssh` (eg. `touch /mnt/ssh`,
   this will enable the SSH server on the pi.)
 * Unmount the sd-card (eg. `umount /mnt`) and remove the sd-card.
 * Place the sd-card into the raspberry pi, connect ethernet, and turn it on.

## Setup SSH access

Now setup the connection from your workstation to the raspberry pi:

 * Find the ip address of the raspberry pi on your router, or via arp (eg. `arp
   -a`; Arch package `net-tools`), or via nmap (eg. `nmap -p 22 192.168.1.0/24`)
 * Create a local ssh key if you don't already have one (`ssh-keygen`)
 * Copy your ssh key over to the pi: `ssh-copy-id X.X.X.X` (replace `X.X.X.X` with the ip address of the pi)
   * Enter the default credentials when it asks (username: `pi` password: `raspberry`)
 * Create an SSH config entry in `$HOME/.ssh/config` like so (replace `X.X.X.X` with the ip address of the pi):
```
Host pi
    Hostname X.X.X.X
    User pi
    ControlMaster auto
    ControlPersist yes
    ControlPath /tmp/ssh-%u-%r@%h:%p
```
 * Now test SSH connection works and SSH into the pi (eg `ssh pi`)

## Setup Raspbian

 * On the pi, edit the file `/boot/config.txt` (eg. `sudo nano /boot/config.txt`)
   * Add the following line at the bottom:
   ```
   gpu_mem=16
   ```
   * This will increase the available amount of RAM by decreasing the amount of
     video RAM. (`16` is the minimum, `0` will not work.)
 * Reboot the pi (`sudo reboot`).
 * After reboot, reconnect via SSH, then run `free -m` to show available RAM. (On a
   raspberry pi 3 with 1G of RAM, you should now see a total of **975MB** whereas before the
   gpu_mem fix it was only **926MB**.)

## Install Docker

 * On the pi, install docker:
   ```
   curl -sSL https://get.docker.com | sh
   ```
 * Add the `pi` user to the docker group:
   ```
   sudo usermod -aG docker pi
   ```
 * Test docker is working:

 ```
 docker run hello-world
 ```
  * If working, you should see a `Hello from Docker!` message and some other help info.

## Setup Docker context

From your workstation, setup the docker context to use the pi docker server
through SSH:

```
docker context create pi --docker "host=ssh://pi"
docker context use pi
```

Now you can run docker commands directly from your workstation, and they will
run on the pi:

```
docker info | grep -iE "(Name|Context)"
```

## Disable Docker daemon if you don't need it

If you are setting up the pi to use as a client workstation only, then
you do not need to run the Docker daemon on the pi. You may disable
the Docker daemon by running:

```
sudo systemctl mask --now docker
```

## Setup Log2Ram

You can increase the expected lifespan of your SD card by installing
[log2ram](https://github.com/azlux/log2ram#log2ram)


## Setup Zram

You can gain a bit more free RAM by installing
[Zram](https://wiki.debian.org/ZRam). Also see [this blog about
ZRam](https://blog.rymcg.tech/blog/linux/zram/)
