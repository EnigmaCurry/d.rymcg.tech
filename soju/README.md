# Soju

[Soju](https://codeberg.org/emersion/soju) is an IRC bouncer with
modern [IRCv3](https://ircv3.net/) features.

## Configure Traefik entrypoint

You must enable the `irc_bouncer` entrypoint in the Traefik config.

 * The Traefik entrypoint listens on port 6698 (TLS)
 * Soju container listens on port 6667 (plain) and Traefik proxies to
   here.

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

## Connect to Soju

Connect to your server via your IRC client of choice. 

Settings:
 
 * Hostname: equal to SOJU_TRAEFIK_HOST
 * Port: 6698 (Same as Traefik `irc_bouncer` entrypoint)
 * Use TLS
 * Username: the admin username you created
 * Password: the admin password you created

## Connect Soju to external IRC network

Once connected to the server, issue the command to create a new network:

```
/bouncer network create -name my_net -addr ircs://irc.example.com:6697 -nick joe -pass my_password
```
