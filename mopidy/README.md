# Mopidy + Snapcast

The [Mopidy](https://mopidy.com/) (MPD) Music Server, with
synchronized [Snapcast](https://github.com/badaix/snapcast#readme)
streaming to multiple player clients.

This copies a lot from
[hamishfagg/dockerfiles](https://github.com/hamishfagg/dockerfiles/tree/master/mopidy-multiroom)
but has been modified to integrate with Traefik and configured to
build from Dockerfile so that it is compatible with ARM64 architecture
(tested on raspberry pi4).

## Prerequisites

### Enable the Traefik MPD entrypoint

The MPD client uses a custom TCP protocol. To proxy this in Traefik,
you must enable the MPD entrypoint on the separate port `6600`, as
well as the Snapcast entrypoint on port `1704`:

 * In your terminal, change to the **traefik** directory.
 * Edit the **traefik** `.env_{DOCKER_CONTEXT}` file, and set:

```
TRAEFIK_MPD_ENTRYPOINT_ENABLED=true
TRAEFIK_SNAPCAST_ENTRYPOINT_ENABLED=true
```

 * Save the .env file and run `make install` to reinstall Traefik.

## Configure Mopidy and Snapcast:

In the `mopidy` directory, run:

```
make config
```

 * Set `MOPIDY_TRAEFIK_HOST` as the hostname to use for mopidy and snapcast.
 * Set `MOPIDY_IP_SOURCERANGE` as the list of CIDR IP ranges allowed
   for clients to connect from, comma separated. (eg. `0.0.0.0/0` to
   allow ALL clients, or `10.10.10.10/32` to enable an exclusive
   client IP address.)
 * Set `MOPIDY_MPD_PASSWORD` as the MPD password the client is
   required to send to authenticate. (randomly set by `make config`.
   Set blank to disable.)

The Traefik MPD entrypoint is a publicly exposed [**unencrypted**
protocol](https://mpd.readthedocs.io/en/latest/protocol.html) for
controlling your music server. TLS is not supported by the majority of
mpd clients, therefore no TLS is applied to the entrypoint. Therefore
it is important to limit access via `MOPIDY_IP_SOURCERANGE` and/or
`MOPIDY_MPD_PASSWORD`. For full privacy, consider running [Traefik
inside a wireguard
VPN](https://github.com/EnigmaCurry/d.rymcg.tech/tree/master/traefik#wireguard-vpn).

Pay attention to the client details printed at the end of the
configuration script, it will give you the `MPD_HOST` variable setting
you can use with your client.

## Install

```
make install
```

```
make open
```

## Configure your MPD client

Mopidy is controlled by the MPD protocol. You can use any MPD client
you want:

 * Here's my [custom keybindings for
   mpc](https://github.com/enigmacurry/mpd_client) with destop
   notifications.
 * Theres [tons of console and desktop
apps](https://wiki.archlinux.org/title/Music_Player_Daemon#Clients):
 * For a full desktop client, I like
   [Sonata](https://github.com/multani/sonata)
 * For android, Check out
   [M.A.L.P](https://f-droid.org/en/packages/org.gateshipone.malp/).

To configure your client, find the `MPD_HOST` environment variable as
shown by `make config`. Set this variable in your `~/.profile` or
wherever else might be appropriate for your system. This sets the
hostname or IP address of the remote mopidy service. The setting may
also include a password prepended (eg. `password@hostname`). Most
clients will honor the `MPD_HOST` variable if it's found to be set in
its environment. Otherwise, you must configure the client manually
with the configured host and password.

## Test the stream

Run `make open` to open the snapcast stream page. Click the play
button to start the stream (it will initially remain silent). This
page can be used to control the volume of all connected clients.

Connect your mpd client, for example, use the standard `mpc` client:

```
## MPD_HOST env var should already be set in ~/.profile :
## export MPD_HOST=password@host

## Test adding a stream from SomaFM:
mpc add https://somafm.com/groovesalad130.pls
mpc play
```

The stream should now be playing in your browser via snapcast. You can
connect other clients, and they will synchronize with all the other
players.

## Configure your snapcast client

To receive the audio stream, you may either play it in your browser,
or receive it via the [snapcast client
protocol](https://github.com/badaix/snapcast/blob/master/doc/binary_protocol.md).

On another computer on the same network, install the `snapclient`
program:

```
# On the client system (running debian / raspbian):
sudo apt update
sudo apt install snapclient

SNAPCAST_HOST=mopidy.example.com
echo "SNAPCLIENT_OPTS=\"-h ${SNAPCAST_HOST}\"" > /etc/default/snapclient

sudo systemctl enable --now snapclient
```

For android devices, check out
[snapdroid](https://github.com/badaix/snapdroid)
