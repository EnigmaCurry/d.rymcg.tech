# Soju

[Soju](https://codeberg.org/emersion/soju) is an IRC bouncer with
modern [IRCv3](https://ircv3.net/) features.

## Configure Traefik entrypoint

You must enable the `irc_bouncer` entrypoint in the Traefik config.

## Config

```
make config
```

 * Enter the domain you want to use 
 * Enter a title for your IRC server

## Install

```
make install
```

## Create admin user

```
make create-admin
```

Choose a username and enter a password for the new user.

Once you've created the user, restart the service:

```
make restart
```

## Connect

Connect to your server via your IRC client of choice. 

Settings:
 
 * Hostname: equal to SOJU_TRAEFIK_HOST
 * Port: 6697 (Same as Traefik `irc_bouncer` entrypoint)
 * Use TLS
 * Username: the admin username you created
 * Password: the admin password you created
