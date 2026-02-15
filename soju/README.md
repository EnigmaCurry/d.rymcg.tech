# Soju

[Soju](https://codeberg.org/emersion/soju) is an IRC bouncer with
modern [IRCv3](https://ircv3.net/) features.

See also:
 - [InspIRCd](../inspircd#readme)
 - [TheLounge](../thelounge#readme)
 

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

See
[clients](https://codeberg.org/emersion/soju/src/branch/master/contrib/clients.md)

Suggestions:

 * [Senpai](https://sr.ht/~delthas/senpai/) (Linux terminal; IRCv3)
 * [Goguma](https://goguma.im/) (android; IRCv3)
 * [TheLounge](../thelounge#readme) (web; not IRCv3)

### Settings for clients that support IRCv3:
 
 * Hostname: use the value of `SOJU_TRAEFIK_HOST`
 * Port: `6698` (use the value from the Traefik `irc_bouncer`
   entrypoint)
 * Use TLS
 * Username: the admin username you created
 * Server Password: the admin password you created
 * No SASL authentication.
 
One of the main benefits of IRCv3 is that you can connect to the
bouncer and access several networks through the single connection, and
when you login from a new client, all of your existing networks will
be automatically accessible.

### Settings for any other IRC clients:

For non-IRCv3 compatible clients, you need to create separate
connections for each backend network you want to connect to. Use the
same settings as above, except that your username changes to include
the backend network.

Format for network specific username:

```
your_username/irc.example.com:6697
```

## Connect Soju to external IRC network

Once connected to the server, issue the command to create a new network:

```
/bouncer network create -name my_net -addr ircs://irc.example.com:6697 -nick joe -pass my_password
```
