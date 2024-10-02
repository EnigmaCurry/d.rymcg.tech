# Peertube

[Peertube](https://github.com/Chocobozzz/PeerTube) is a free, decentralized
and federated video platform developed as an alternative to other platforms
that centralize our data and attention, such as YouTube, Dailymotion or Vimeo.

Peertube is a video streaming service, and while you don't need super beefy
hardware to run it, you do want hardware that can handle it. Read Peertube's
hardware recommendations [here](https://joinpeertube.org/faq#should-i-have-a-big-server-to-run-peertube).

Also, keep in mind that videos take up a lot of space. You may want to consider
increasing your host's storage or symlinking `/var/lib/docker/volumes/peertube_data/`
on the host to a mountpoint for external storage.

## Config

```
make config
```

This will ask you to enter the domain name to use.

To use Peertube's livestreaming, you have to enable either the RTMP or RTMPS
Traefik entrypoint.

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external authentication on
top of your app.

## Install

```
make install
```

After installation, you can find the randomly-generated default password for
the admin user ("root") in the logs (`make logs service=peertube`). You should
change this password in the UI when you first login.

## Open

```
make open
```

This will automatically open the page in your web browser, and will
prefill the HTTP Basic Authentication password if you enabled it
(and chose to store it in `passwords.json`).

## Destroy

```
make destroy
```

This completely removes the container and deletes all its volumes.
