# InspIRCd

[InspIRCd](https://www.inspircd.org/) is an Internet Relay Chat (IRC) server.

## Configure Traefik entrypoint

You must enable the `irc` entrypoint in the Traefik config.

 * The Traefik entrypoint listens on port 6697 (default; TLS)
 * InspIRCd container listens on port 6667 (plain) and Traefik proxies
   to here.

## Config

```
make config
```

## Install

```
make install
```

## Connect

Connect to your server via [soju](../soju#readme) or your IRC
client/bouncer of choice.

Settings:
 
 * Hostname: equal to SOJU_TRAEFIK_HOST
 * Port: 6697 (Same as Traefik `irc_bouncer` entrypoint)
 * Use TLS
 * Username: the admin username you created
 * Password: the admin password you created

