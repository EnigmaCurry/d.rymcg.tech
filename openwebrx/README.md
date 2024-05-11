# OpenWebRX

[OpenWebRX](https://github.com/jketterl/openwebrx) is a multi-user SDR
receiver (Software Defined Radio / ham radio) software with a web interface.

## Blacklist modules

You must configure the Docker host operating system to blacklist the
kernel modules of the devices you wish to use with OpenWebRX,
otherwise the host will steal the device and the container won't be
able to access them.

For example, for RTL-SDR devices, create the blacklist file on the
**host** system:

```
## SSH into your Docker host system and blacklist the modules you need:
cat <<EOF > /etc/modprobe.d/openwebrx-blacklist-modules.conf
blacklist dvb_usb_rtl28xxu
blacklist sdr_msi3101 
blacklist msi001
blacklist msi2500
blacklist hackrf
EOF
```

> [!NOTE] 
> This list of modules may not be exhaustive, check what modules are
> loaded when you plug the device in. Compare `lsmod` before and
> after reboot or when you plug something in. 

Reboot the server for the changes to take effect. Double check that
the modules are NOT loaded after reboot.

## Find the device bus

You need to find the bus path(s) that the your device(s) are plugged
into.

On the host server, run:

```
lsusb
```

For example, the output may show the following:

```
Bus 005 Device 003: ID 0bda:2838 Realtek Semiconductor Corp. RTL2838 DVB-T
```

This indicates that it found an RTL-SDR devices on Bust `005` Device
`003`, therefore the bus path will be `/dev/bus/usb/005/003`. You will
need to enter this path in your `docker-compose.yaml` on your
workstation.

## Config

On your workstation, in the openwebrx directory, run:

```
make config
```

This creates the `.env_{CONTEXT}` file. Most of the configuration must
be done by hand by editing the file.

 * Edit the `docker-compose.yaml` and add all of the device paths for
   each of your devices. For example, if your device bus path is
   `/dev/bus/usb/005/003`, you need to add the device mapping like
   this in `docker-compose.yaml`:
   
```
    devices:
      - /dev/bus/usb/005/003:/dev/bus/usb/005/003
```

## Install

```
make install
```

## Post-install setup

There is no default username / password, you must set it up after its
installed.

See the [OpenWebRX User Managerment
docs](https://github.com/jketterl/openwebrx/wiki/User-Management)

You can enter the container shell to run the necessary commands:

```
make shell
```

> ![NOTE]
> For the docker version of the OpenWebRX you should use the `/opt/openwebrx/openwebrx.py` file instead of the literal command `openwebrx`.

To create a user, do the following inside the shell:

```
./openwebrx.py admin adduser ryan
```

You'll want to login with the user and go into the settings page to
finish the configuration.


