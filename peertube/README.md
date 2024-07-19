# peertube

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

### Authentication and Authorization

Running `make config` will ask whether or not you want to configure
authentication for your app (on top of any authentication your app provides).
You can configure OpenID/OAuth2 or HTTP Basic Authentication.

OAuth2 uses traefik-forward-auth to delegate authentication to an external
authority (eg. a self-deployed Gitea instance). Accessing this app will
require all users to login through that external service first. Once
authenticated, they may be authorized access only if their login id matches the
member list of the predefined authorization group configured for the app
(`PEERTUBE_OAUTH2_AUTHORIZED_GROUP`). Authorization groups are defined in the
Traefik config (`TRAEFIK_HEADER_AUTHORIZATION_GROUPS`) and can be
[created/modified](https://github.com/EnigmaCurry/d.rymcg.tech/blob/master/traefik/README.md#oauth2-authentication)
by running `make groups` in the `traefik` directory.

For HTTP Basic Authentication, you will be prompted to enter username/password
logins which are stored in that app's `.env_{INSTANCE}` file.

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
