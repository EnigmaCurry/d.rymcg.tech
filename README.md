# d.rymcg.tech

This is a docker-compose project consisting of Traefik as a TLS HTTPS proxy, and
other various services behind this proxy. Each project is in its own
sub-directory containing its own `docker-compose.yaml` and `.env` file (and
`.env-dist` sample file), this structure allows you to pick and choose which
services you wish to enable.

The `.env` files are secret, and excluded from being comitted to the git
repository, via `.gitignore`. Each project includes a `.env-dist` file which is
a sample that must be copied, creating your own secret `.env` file, and edit
appropriately.

## Create the proxy network

Since each project is in separate docker-compose files, you must use an
`external` docker network. All this means is that you manually create the
network yourself and reference this network in the compose files. (`external`
means that docker-compose will not attempt to create nor destroy this network
like it usually would.)

Create the new network for Traefik, as well as all of the apps that will be
proxied:

```
docker network create traefik-proxy
```

Each docker-compose file will use this snippet in order to connect to traefik:

```
networks:
  traefik-proxy:
    external:
      name: traefik-proxy

service:
  APP_NAME:
    networks:
    ## Connect to the Traefik proxy network (allows to be exposed):
    - traefik-proxy
    ## If there are additional containers for the backend,
    ## also connect to the default (not exposed) network:
    - default
```

## Traefik

Copy `.env-dist` to `.env` and edit the following:

 * `ACME_CA_SERVER` this is the Let's Encrypt API (ACME) server to use. 
 
   * For development/staging use
     `https://acme-staging-v02.api.letsencrypt.org/directory`
   * For production use `https://acme-v02.api.letsencrypt.org/directory`
   
 * `ACME_CA_EMAIL` this is YOUR email address, where you will receive notices
   from Let's Encrypt regarding your domains and related certificates.

To start traefik, go into the traefik directory and run `docker-compose up -d`

## Gitea

Gitea is a git repository host as well as an OAuth server. You can use it to
store your git repositories, but more importantly for our purposes, it can
integrate with
[thomseddon/traefik-forward-auth](https://github.com/thomseddon/traefik-forward-auth)
(TODO) so that it can act as an authentication middleware for Traefik, ensuring
that only valid accounts can access protected containers. Traefik will pass the
`X-Forwarded-User` header containing the authenticated user, so that the
container itself can do per-user authorization if needed.

Copy `.env-dist` to `.env` and edit the following:

 * `GITEA_TRAEFIK_HOST` to the external domain name forwarded from traefik, eg.
   `git.example.com`

Bring up the service with `docker-compose up -d`, then immediately open the
domain in your browser to finish the setup procedure. Most of the data in the
form should be pre-filled and correct, but you still need to setup an
adminstrator account and password (at the very bottom, expand the section.)

Traefik listens for SSH connections on TCP port 2222 and forwards directly to
the builtin Gitea SSH service.

## tt-rss

[ttrss-docker-compose](https://git.tt-rss.org/fox/ttrss-docker-compose.git) was
copied into the `ttrss` directory and some light modifications were made to its
docker-compose file to get it to work with traefik. Follow the upstream [ttrss
README](ttrss/README.md) which is still unmodified, but also consider these
additions for usage with Traefik:

 * Set `TTRSS_TRAEFIK_HOST` (this is a new custom variable not in the upstream
   version) to the external domain name you want to forward in from traefik.
   Example: `tt-rss.example.com` (just the domain part, no https:// prefix and
   no port number)
 * Set `TTRSS_SELF_URL_PATH` with the full URL of the app, eg.
   `https://tt-rss.example.com/tt-rss` (The path `/tt-rss` at the end is
   required, but the root domain will automatically forward to this.)
 * Setting `HTTP_PORT` is unnecessary and is now ignored.
 

## baikal

baikal is a CAL-DAV server. 

Copy .env-dist to .env and change:

 * `BAIKAL_TRAEFIK_HOST` to the external domain name forwarded from traefik, eg.
   `cal.example.com`
 
To start baikal, go into the baikal directory and run `docker-compose up -d`

Immediately configure the application, by going to the external URL in your
browser, it is unsecure by default until you set it up!

## nextcloud

Copy .env-dist to .env, and edit variables accordingly. 

 * `NEXTCLOUD_TRAEFIK_HOST` the external domain name to forward from traefik.
 * `MYSQL_PASSWORD` you must choose a secure password for the database.

Start with `docker-compose up -d`

Visit the configured domain name in your browser to finish the installation.
Choose MySQL/MariaDB for the database, enter the details:

 * Username: nextcloud
 * Database: nextcloud
 * Database host: mariadb
 * Password: same as you configured in .env `MYSQL_PASSWORD`
 
## nodered

Copy .env-dist to .env, and edit variables accordingly. 

 * `NODERED_TRAEFIK_HOST` the external domain name to forward from traefik.
 * `NODERED_HTTP_AUTH` - HTTP Basic Authentication Password hashed with
   htpasswd.
 
Node-RED does not provide any authentication, so Traefik can limit access via
HTTP Basic Authentication, which requires a username and password for access.
The password must be hashed with the `htpasswd` utility, and then saved in the
.env file.

Create a random password hash with the username `admin`:

```
(
 USERNAME=admin
 PLAIN_PASSWORD=$(openssl rand -base64 30 | head -c 20)
 HASH_PASSWORD=$(echo $PLAIN_PASSWORD | docker run -i --rm httpd:2.4 htpasswd -inB ${USERNAME})
 echo "Username: ${USERNAME}"
 echo "Plain text password: ${PLAIN_PASSWORD}"
 echo "Hashed user/password: ${HASH_PASSWORD}"
)
```

Copy the hashed user/password text and paste into the `.env` variable
`NODERED_HTTP_AUTH`. Start the container with `docker-compose up -d` then login
to the app with the username `admin` and the plain text password.


## mosquitto

Mosquitto is an MQTT pub/sub broker. You can use it in combination with node-red
for sending/receiving messages. 

Good blog posts:

 * [S-MQTTT, or: secure-MQTT-over-Traefik](https://jurian.slui.mn/posts/smqttt-or-secure-mqtt-over-traefik/)
 * [MQTT – How to use ACLs and multiple user accounts](https://blog.jaimyn.dev/mqtt-use-acls-multiple-user-accounts/)

Copy .env-dist to .env and edit the variables:

 * `MOSQUITTO_TRAEFIK_HOST` the external domain name to forward from traefik.
 
Start mosquitto initially only using the default config: `docker-compose up -d`

Create an initial admin account in order to test with (_WARNING: `-c` will
overwrite any existing password file without confirmation, so in the future when
you want to create further accounts, do not use the `-c` parameter!_):

```
(
  USERNAME=admin
  PASSWORD=$(openssl rand -base64 24)
  docker exec -it mosquitto mosquitto_passwd -c -b /mosquitto/config/passwd ${USERNAME} ${PASSWORD}
  echo "Created password database, initial user account:"
  echo "username: ${USERNAME}"
  echo "password: ${PASSWORD}"
)
```

Copy the main config file, and the ACL config file, into the volume (you must do
this again in the future, anytime you modify these configs):

```
docker cp mosquitto.conf mosquitto:/mosquitto/config/mosquitto.conf
docker cp acl.conf mosquitto:/mosquitto/config/acl.conf
```

Restart mosquitto in order to reload the config:

```
docker-compose restart
```
