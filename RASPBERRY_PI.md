# Docker on Raspberry Pi

## Install Rasbian

The best way to install raspbian onto an sd-card is to use the
rpi-imager from another computer, which allows you to setup the user
account, network settings, and SSH credentials all from the imager
software.

 * [Download the Raspberry PI
   Imager](https://www.raspberrypi.com/software/) or install
   `rpi-imager` from your package manager.
 * Run `rpi-imager`.
 * Click on the menu labled `Rasperry Pi Device`.
   * Choose your model of raspberry pi.
   
 * Click on the menu labeled `Operating System`
   * Choose `Raspberry PI OS (other)`
   * Choose `Raspberry PI OS Lite (64-bit)`.
   
 * Click on the menu labeled `Storage`.
   * Choose the Storage device to install to.
   * You may need to change the ownership of the device (eg. I had to
     do `sudo chown ryan /dev/sdb` first).
     
 * Click `Next`.
 
 * Click `Edit Settings`.
 
   * On the `General` tab:
   
     * Enter the hostname
     * Enter a username and password.
     * Optionally setup the Wifi (I just ethernet instead).
     * Set locale settings. I set mine to UTC.
     
   * On the `Services` tab:
   
     * Click `Enable SSH`
     * Choose `Allow pulbic-key authentication only`
     * Paste the list of your SSH public keys into the box. (Find them
       on your workstation by running `ssh-add -L` or look in
       ``~/.ssh/*.pub`)
       
   * On the `Options` tab:
   
     * Unselect `Enable telemetry` unless you're into that sort of
       thing.
       
 * Click `Yes` to the question `Would you like to apply OS custom settings`.
 
 * Confirm you would like to write to the sd-card and wait for it to complete.
 
 * Once complete, unplug the sd-card, put it into the raspberry pi,
   plug in the ethernet, and power it on.

## Setup ssh config on your workstation

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

## Setup Log2Ram

You can increase the expected lifespan of your SD card by installing
[log2ram](https://github.com/azlux/log2ram#log2ram)
