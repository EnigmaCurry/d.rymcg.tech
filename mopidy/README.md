# Mopidy + Snapcast

This is the [Mopidy](https://mopidy.com/) Music Server, with
integrated [Music Player Daemon](https://www.musicpd.org/) (MPD), and
with synchronized
[Snapcast](https://github.com/badaix/snapcast#readme) streaming to
multiple player clients.

This copies a lot from
[hamishfagg/dockerfiles](https://github.com/hamishfagg/dockerfiles/tree/master/mopidy-multiroom)
but has been modified to integrate with Traefik and configured to
build itself from Dockerfile so that it is compatible with ARM64
architecture (tested on raspberry pi4).

## How this works

Mopidy is a server that can load music from various sources that it
knows how to communicate with. [MPD](https://www.musicpd.org/) is a
classic module builtin to Mopidy that can load music from the
filesystem, as well as stream from Icecast radio stations. MPD is only
the control interface for navigating the library, queueing tracks, and
playback controls. MPD clients are ubiquitous, and available for every
platform. An MPD client is used to remotely control the playback of
the server, it does not play audio.

Snapcast broadcasts the audio channel to the multicast network. The
Snapcast server takes the audio output from Mopidy and streams it to
all connected clients. Snapcast clients will synchronize their
playback with eachother, so that you can play the same stream in
multiple rooms of the same home without interference. Snapcast clients
are available for several platforms, including Linux and the Web. Use
an old android phone as a playback client (with a headphone jack
connected to some bigger speakers). Stream to all the devices in your
home and produce interesting spatial acoustics with almost no
perceptable delay in output.

## Prerequisites

### Enable the Traefik MPD and Snapcast entrypoints

The MPD client uses a custom TCP protocol. To proxy this in Traefik,
you must enable the MPD entrypoint on the separate port `6600`, as
well as the Snapcast entrypoint on port `1704`:

 * In your terminal, change to the [**traefik**](../traefik) directory.
 * Edit the **traefik** `.env_{DOCKER_CONTEXT}` file, and set:

```
TRAEFIK_MPD_ENTRYPOINT_ENABLED=true
TRAEFIK_SNAPCAST_ENTRYPOINT_ENABLED=true
```

 * Save the .env file and run `make install` to reinstall Traefik.
 * If you enabled the Traefik dashboard, you can run `make open` and
   verify that the `MPD` and `Snapcast` entrypoints were succesfully
   created.

## Configure Mopidy and Snapcast:

In the `mopidy` directory, run:

```
make config
```

 * Set `MOPIDY_TRAEFIK_HOST` as the hostname to use for mopidy and snapcast.
 * Set `MOPIDY_MPD_PASSWORD` as the MPD password the client is
   required to send to authenticate. (randomly set by `make config`.
   Set blank to disable.)
 * Set `MOPIDY_MPD_IP_SOURCERANGE` as the list of CIDR IP ranges for
   the MPD clients allowed to connect, comma separated. (eg.
   `0.0.0.0/0` to allow ALL clients, or `10.10.10.10/32` to enable an
   exclusive client IP address.)
 * Set `MOPIDY_SNAPCAST_IP_SOURCERANGE` as the list of CIDR IP ranges
   for the Snapcast clients allowed to connect, comma separated. (eg.
   `0.0.0.0/0` to allow ALL clients, or `10.10.10.10/32` to enable an
   exclusive client IP address.)

The Traefik MPD entrypoint is a publicly exposed [**unencrypted**
protocol](https://mpd.readthedocs.io/en/latest/protocol.html) for
controlling your music server. TLS is not supported by the majority of
mpd clients, therefore no TLS is applied to the entrypoint. It is
important to limit access via `MOPIDY_MPD_IP_SOURCERANGE`,
`MOPIDY_SNAPCAST_IP_SOURCERANGE` and/or `MOPIDY_MPD_PASSWORD`. For
full privacy, consider running [Traefik inside a wireguard
VPN](https://github.com/EnigmaCurry/d.rymcg.tech/tree/master/traefik#wireguard-vpn),
or have the host behind a firewall to serve a local area network only.

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

The snapcast control page is now opened in your web browser. You can
use this page to see all the connected snapcast clients, control their
individual volumes, as well as press the Play button to connect your
browser itself as a streaming client. Load this same page on devices
throughout your house, to maky any device a client.

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

Remember, the IP address of all clients must be within one of the CIDR
ranges specified in `MOPIDY_MPD_IP_SOURCERANGE`, otherwise access is
denied.

## Test the stream

Run `make open` to open the snapcast stream page. Click the play
button to start the stream (it will initially remain silent). This
page can be used to control the volume of all connected clients.

Connect your mpd client, for example, use the standard `mpc` client:

```
## MPD_HOST env var should already be set in ~/.profile :
## export MPD_HOST=password@host

## For safety, set the initial volume low:
mpc volume 10

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

On another computer, install the `snapclient` program:

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

Remember, the IP address of all clients must be within one of the CIDR
ranges specified in `MOPIDY_SNAPCAST_IP_SOURCERANGE`, otherwise access
is denied.

## Adding music

When mopidy is installed, the `mopidy_music` Docker volume is created.
This is an empty volume that you can store your music files in.

You can setup the [sftp](../sftp) container to conveniently manage
these files with rsync or sshfs. Here are the brief instructions for
setting up sftp (read the [sftp README](../sftp/README.md) for more
details):

 * Install mopidy as described above.
 * In the [traefik](../traefik) directory:
    * Edit your Traefik `.env_{DOCKER_CONTEXT}` file, and turn on the
      SSH entrypoint, set `TRAEFIK_SSH_ENTRYPOINT_ENABLED=true`.
    * Run `make install` to restart Traefik with the new config.

 * In the [sftp](../sftp) directory:
    * Run `make config`
      * Set the `SFTP_PORT` to `2223` (default)
      * Set the `SFTP_USERS` to `yourname:1000` (replace `yourname`
        with any name you like, `1000` is the correct UID for mopidy.)
      * Set the `SFTP_VOLUMES` to `mopidy_music:yourname:music`:
         * `mopidy_music` is the name of the Mopidy Docker volume .
         * Replace `yourname` with the same name you set in
           `SFTP_USERS`.
         * `music` is the symlinked directory name inside of SFTP.
     * Run `make install`
     * Run `make ssh-copy-id` to copy your workstation SSH pubkeys to
       the SFTP container. Enter the name `yourname` when prompted
       (replace `yourname` with the same name as in `SFTP_USERS`)

In your workstation's `~/.ssh/config` file, add a config for the SFTP
account you just created (replace `sftp.example.com` and `yourname`
appropriately):

```
Host sftp.example.com
     Port 2223
     User yourname
```

Now mount the volume with `sshfs`:

```
## Run in the sftp directory:
make sshfs
```

Now you should be able to copy your music into the local mountpoint:
`~/mnt/sftp.{ROOT_DOMAIN}/music`

Once you've added some files, you should run the initial scan:

```
## Run in the mopidy directory:
make library
```

You can re-run `make library` anytime you add new music. (I don't know
why, but updating the library from the mpd client is not working.)


## Enabling SoundCloud

You can listen to soundcloud on mopidy, using your own soundcloud
account. 

 * [Authorize Mopidy to access
   SoundCloud](https://mopidy.com/ext/soundcloud/)
 * Copy the displayed `auth_toke` value, and paste into your
   `.env_{DOCKER_CONTEXT}` file:

```
##
MOPIDY_SOUNDCLOUD_ENABLED=true
MOPIDY_SOUNDCLOUD_AUTH_TOKEN=xxxxxxxxxxxxxxx
```

Run `make install` to reinstall with new configuration.

Check the logs in order to make sure there are no authentication
errors. `make logs service=mopidy`.

You should find a `SoundCloud` directory in your mpd client library.
