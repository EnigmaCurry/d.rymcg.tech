# Icecast

[Icecast](https://icecast.org/) is a streaming multimedia server
supporting Ogg (Vorbis and Theora), Opus, WebM and MP3 streams. It is
compatible with [Shoutcast](https://en.wikipedia.org/wiki/SHOUTcast)

## Configure

```
make config
```

Icecast uses different passwords for different roles: Sources, Relays
and , Admin. `make config` will create randomized passwords and save
them to your `.env_{DOCKER_CONTEXT}` file.

If your client does not support TLS, you can bind the icecast port
directly to the docker host. Set `ICECAST_ALLOW_DIRECT_MAP_PORT=true`
and `ICECAST_DIRECT_MAP_PORT=8001` (or whatever port you want) in the
env file.

## Install

```
make install
```

```
make open
```

# Stream live audio from Pipewire / Pulseaudio

To stream audio from another computer, you can use
[darkice](https://github.com/rafael2k/darkice/) (install from [Arch
AUR](https://aur.archlinux.org/packages/darkice)). The client computer
must be running [pipewire](https://wiki.archlinux.org/title/PipeWire)
or [pulseaudio](https://wiki.archlinux.org/title/Pulseaudio).

Darkice requires direct access to icecast, without the proxy through
Traefik. For this you must set `ICECAST_ALLOW_DIRECT_MAP_PORT=true`
and `ICECAST_DIRECT_MAP_PORT=8001` (or whatever port you want).

On the client computer, create a `null` pulseaudio audio sink device,
named `icecast`:

```
pactl load-module module-null-sink sink_name=icecast
```

Use a tool like `pasystray` to route any application's audio output
(eg. your web browser) to the new `icecast` sink.

Create a config file for darkice, making sure to change the following
settings for your own environment:

 * Change `icecast.example.com` to the same host as your
   `ICECAST_TRAEFIK_HOST`.
 * Change the password `xxxxxxx` to the same value as your
   `ICECAST_AUTHENTICATION_SOURCE_PASSWORD`
 * Change the port `8001` to the same value as your `ICECAST_DIRECT_MAP_PORT`.

Save the config file to `~/.config/darkice/default.cfg`:

```
## ~/.config/darkice/default.cfg
# sample DarkIce configuration file, edit for your needs before using
# see the darkice.cfg man page for details

# this section describes general aspects of the live streaming session
[general]
duration        = 0        # duration of encoding, in seconds. 0 means forever
bufferSecs      = 5         # size of internal slip buffer, in seconds
reconnect       = yes       # reconnect to the server(s) if disconnected
realtime        = yes       # run the encoder with POSIX realtime priority
rtprio          = 3         # scheduling priority for the realtime threads

# this section describes the audio input that will be streamed
[input]
device          = pulseaudio # Use Pulseaudio sink
sampleRate      = 44100      # sample rate in Hz. try 11025, 22050 or 44100
bitsPerSample   = 16         # bits per sample. try 16
channel         = 2          # channels. 1 = mono, 2 = stereo
paSourceName    = icecast.monitor

# this section describes a streaming connection to an IceCast2 server
# there may be up to 8 of these sections, named [icecast2-0] ... [icecast2-7]
# these can be mixed with [icecast-x] and [shoutcast-x] sections
[icecast2-0]
bitrateMode     = abr       # average bit rate
format          = mp3       # format of the stream: ogg vorbis
bitrate         = 256       # bitrate of the stream sent to the server
server          = icecast.example.com
                            # host name of the server
port            = 8001      # port of the IceCast2 server, usually 8000
password        = xxxxxxx
mountPoint      = darkice   # mount point of this stream on the IceCast2 server
name            = DarkIce
                            # name of the stream
description     = DarkIce
                            # description of the stream
url             = http://www.yourserver.com
                            # URL related to the stream
genre           = my own    # genre of the stream
public          = yes       # advertise this stream?
localDumpFile	= dump.mp4  # local dump file
```

You can start the darkice client for testing:

```
darkice -c ~/.config/darkice/default.cfg
```

You can enable the systemd unit so that it starts up automatically:

```
systemctl --user enable --now darkice@default
```

Use any pulseaudio/pipewire compatible routing client you wish (eg.
`pasystray`). Route the audio from your web browser to the `icecast`
sink. Play some audio in your web browser, although you won't hear
anything, it should now be streaming to the icecast server.

You can test the stream with any player:

```
vlc https://icecast.example.com/darkice
```
