# Mopidy + Snapcast

The [Mopidy](https://mopidy.com/) (MPD) Music Server, with
synchronized [Snapcast](https://github.com/badaix/snapcast#readme)
streaming to multiple player clients.

This copies a lot from
[hamishfagg/dockerfiles](https://github.com/hamishfagg/dockerfiles/tree/master/mopidy-multiroom)
but has been modified to integrate with Traefik and configured to
build from Dockerfile so that is compatible with ARM64 architecture
(tested on raspberry pi4).

## Prerequisites

### Enable the Traefik MPD entrypoint

The MPD client uses a custom TCP protocol. To proxy this in Traefik,
you must enable the MPD entrypoint on the separate port `6600`, as
well as the Snapcast entrypoint on port `1704`:

 * In your terminal, change to the **traefik** directory.
 * You must reconfigure the **traefik** `.env_{DOCKER_CONTEXT}` file,
   and set:

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

 * Set `MOPIDY_TRAEFIK_HOST` to use as the hostname for mopidy and snapcast.
 * Set `MOPIDY_IP_SOURCERANGE` as the list of CIDR IP ranges allowed
   for clients to connect from, comma separated. (eg. `0.0.0.0/0` to
   allow ALL clients, or `10.10.10.10/32` to enable an exclusive
   client IP address.)
 * Set `MOPIDY_MPD_PASSWORD` (randomly set) as the MPD password the
   client is required to send to authenticate.

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

You can use any MPD client you want:
 * There's my [custom keybindings for
   mpc](https://github.com/enigmacurry/mpd_client) with destop
   notifications.
 * Theres [tons of console and desktop
apps](https://wiki.archlinux.org/title/Music_Player_Daemon#Clients):
 * For a full desktop client, I like
   [Sonata](https://github.com/multani/sonata)
 * For android, Check out
   [M.A.L.P](https://f-droid.org/en/packages/org.gateshipone.malp/).


To configure your client, use the `MPD_HOST` variable as shown by
`make config`. Most clients will honor the `MPD_HOST` variable if
found. Otherwise, you must configure the Host and Password in the
client configuration.

## Test the stream

Run `make open` to open the snapcast stream page. Click the play
button to start the stream.

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
