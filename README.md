# d.rymcg.tech

This is a docker-compose project consisting of Traefik as a TLS HTTPS proxy, and
other various services behind this proxy. Each project is in its own
sub-directory containing its own `docker-compose.yaml` and `.env` file (and
`.env-dist` sample file), this structure allows you to pick and choose which
services you wish to enable.

The `.env` files are secret, and excluded from being committed to the git
repository, via `.gitignore`. Each project includes a `.env-dist` file which is
a sample that must be copied, creating your own secret `.env` file, and edit
appropriately.

For this project, all configuration must be done via:

 * Environment variables (preferred)
 * Copied config files into a named volume (in the case that the container
   doesn't support env variables)

Many examples of docker-compose that you may find on the internet will have host
mounted files, which allows containers to access files directly from the host
filesystem. **Host mounted files are considered an anti-pattern and will never
be used in this project.** For more infomration see [Rule 3 of the 12 factor app
philosophy](https://12factor.net/config). By following this rule, you can safely
use docker-compose from a remote client (over SSH with the `DOCKER_HOST`
variable set) and by doing so, you can ensure you are working with a clean state
on the host.

* [Setup](#setup)
* [Traefik](#traefik)
* [Gitea](#gitea)
* [Tiny Tiny RSS](#tiny-tiny-rss)
* [Baikal](#baikal)
* [Nextcloud](#nextcloud)
* [CryptPad](#cryptpad)
* [Node-RED](#node-red)
* [Mosquitto](#mosquitto)
* [Bitwarden](#bitwarden)
* [Shaarli](#shaarli)
* [xBrowserSync](#xbrowsersync)
* [Piwigo](#piwigo)
* [SFTP](#sftp)
* [Syncthing](#syncthing)

## Setup
### Create a docker host

[Install docker Server](https://docs.docker.com/engine/install/#server) or see
[DIGITALOCEAN.md](DIGITALOCEAN.md) for instructions on creating a docker host on
DigitalOcean.

### Create the proxy network

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

[Traefik](https://github.com/traefik/traefik) is a modern
HTTP reverse proxy and load balancer.

Copy `.env-dist` to `.env` and edit the following:

 * `ACME_CA_EMAIL` this is YOUR email address, where you will receive notices
   from Let's Encrypt regarding your domains and related certificates.

To start Traefik, go into the traefik directory and run `docker-compose up -d`

All other services defines the `ACME_CERT_RESOLVER` variable in their respective
`.env` file. There are two different environments defined, `staging` (default)
and `production`. Staging will create untrusted TLS certificates for testing
environments. Production will generate browser trustable TLS certificates.

## Gitea

[Gitea](https://gitea.com/) is a git repository host as well as an OAuth
server. You can use it to store your git repositories, but more importantly
for our purposes, it can integrate with
[thomseddon/traefik-forward-auth](https://github.com/thomseddon/traefik-forward-auth)
(TODO) so that it can act as an authentication middleware for Traefik, ensuring
that only valid accounts can access protected containers. Traefik will pass the
`X-Forwarded-User` header containing the authenticated user, so that the
container itself can do per-user authorization if needed.

Copy `.env-dist` to `.env`, and edit variables accordingly. 

 * `GITEA_TRAEFIK_HOST` to the external domain name forwarded from traefik, eg.
   `git.example.com`

Bring up the service with `docker-compose up -d`, then immediately open the
domain in your browser to finish the setup procedure. Most of the data in the
form should be pre-filled and correct, but you still need to setup an
adminstrator account and password (at the very bottom, expand the section.)

Traefik listens for SSH connections on TCP port 2222 and forwards directly to
the builtin Gitea SSH service.

## Tiny Tiny RSS

[Tiny Tiny RSS](https://tt-rss.org/) is a free and open source web-based
news feed (RSS/Atom) reader and aggregator.

[ttrss-docker-compose](https://git.tt-rss.org/fox/ttrss-docker-compose.git) was
copied into the `ttrss` directory and some light modifications were made to its
docker-compose file to get it to work with traefik. Follow the upstream [ttrss
README](ttrss/README.md) which is still unmodified, but also consider these
additions for usage with Traefik:

Copy `.env-dist` to `.env`, and edit variables accordingly. 

 * Set `TTRSS_TRAEFIK_HOST` (this is a new custom variable not in the upstream
   version) to the external domain name you want to forward in from traefik.
   Example: `tt-rss.example.com` (just the domain part, no https:// prefix and
   no port number)
 * Set `TTRSS_SELF_URL_PATH` with the full URL of the app, eg.
   `https://tt-rss.example.com/tt-rss` (The path `/tt-rss` at the end is
   required, but the root domain will automatically forward to this.)
 * Setting `HTTP_PORT` is unnecessary and is now ignored.
 
To start TT-RSS, go into the ttrss directory and run `docker-compose up -d`. 

## Baikal

[Baikal](https://sabre.io/baikal/) is a lightweight CalDAV+CardDAV server. 

Copy `.env-dist` to `.env`, and edit variables accordingly. 

 * `BAIKAL_TRAEFIK_HOST` to the external domain name forwarded from traefik, eg.
   `cal.example.com`
 
To start baikal, go into the baikal directory and run `docker-compose up -d`.

Immediately configure the application, by going to the external URL in your
browser, it is unsecure by default until you set it up!

## Nextcloud

[Nextcloud](https://nextcloud.com/) is an on-premises content collaboration
platform.

Copy `.env-dist` to `.env`, and edit variables accordingly. 

 * `NEXTCLOUD_TRAEFIK_HOST` the external domain name to forward from traefik.
 * `MYSQL_PASSWORD` you must choose a secure password for the database.

To start Nextcloud, go into the nextcloud directory and run `docker-compose up -d`.

Visit the configured domain name in your browser to finish the installation.
Choose MySQL/MariaDB for the database, enter the details:

 * Username: nextcloud
 * Database: nextcloud
 * Database host: mariadb
 * Password: same as you configured in .env `MYSQL_PASSWORD`
 
## CryptPad

[CryptPad](https://cryptpad.fr/) is an encrypted, open source collaboration
suite.

CryptPad is designed to serve its content over two domains. Account passwords
and cryptographic content is handled on the 'main' domain, while the user
interface is loaded from a 'sandbox' domain.

Copy `.env-dist` to `.env`, and edit these variables: 

 * `CPAD_MAIN_DOMAIN` the external domain name to forward from traefik for
 the main site.
 * `CPAD_SANDBOX_DOMAIN` the external domain name to forward from traefik for
 sandboxed content.

Cryptpad requires a configuration file (config.js) :

 * Copy `config.example.js` to `config.js` in the same directory.
 * Edit the `httpUnsafeOrigin` field, and put the same value as you used for
   `CPAD_MAIN_DOMAIN`, for example `https://pad.example.com`.
 * Edit the `httpSafeOrigin` field, and put the same value as you used for
   `CPAD_SANDBOX_DOMAIN`, for example `https://pad.box.example.com`.
 * Editing the rest of the fields is optional, you may wish to change
   `adminEmail` if you want the in-app support links to work.

You must start cryptpad initially using the default config, then you can copy
your config into the container volume, and then restart. Once restarted, the
container will be running with your edited config.
 
 * Run `docker-compose up -d` to start the container.
 * Copy the config: `docker cp config.js cryptpad:/cryptpad/config/config.js`
 * Run `docker-compose restart`
 * You must re-do this process anytime you change `config.js`.
 
Visit the main domain in your browser, and sign up for an account. Go to the
user settings page, and find your public signing key (example:
`[cryptpad-user1@my.awesome.website/YZgXQxKR0Rcb6r6CmxHPdAGLVludrAF2lEnkbx1vVOo=]`)
 
Edit `config.js` again, and uncomment the `adminKeys` section and add your user
key (and remove the example key). Copy the config.js to the volume again using
`docker cp` and restart the container again. Now your user can access the
(limited) adminstration page to edit some addtional settings using the web app.

## Node-RED

[Node-RED](https://nodered.org/) is a programming tool for wiring together
hardware devices, APIs and online services in new and interesting ways.

Copy `.env-dist` to `.env`, and edit variables accordingly. 

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


## Mosquitto

[Mosquitto](https://mosquitto.org/) is an MQTT pub/sub broker. You can use it in combination with node-red
for sending/receiving messages. 

Good blog posts:

 * [S-MQTTT, or: secure-MQTT-over-Traefik](https://jurian.slui.mn/posts/smqttt-or-secure-mqtt-over-traefik/)
 * [MQTT – How to use ACLs and multiple user accounts](https://blog.jaimyn.dev/mqtt-use-acls-multiple-user-accounts/)

Copy `.env-dist` to `.env`, and edit variables accordingly. 

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

## Bitwarden

[Bitwarden](https://bitwarden.com/) is an open-source password manager.

Copy `.env-dist` to `.env`, and edit variables accordingly. 

 * `BITWARDEN_PORT` the external port you'll use to connect to Bitwarden.

To start Bitwarden, go into the bitwarden directory and run `docker-compose up -d`.

This configuration doesn't use Traefik - you should SSH tunnel into the
host, then access Bitwarden via localhost:<whatever port you designate in .env>

E.g., if you set the port to 8888:

```
ssh docker -L 8888:localhost:8888
```

Then in your web browser, access `http://localhost:8888`

## Shaarli

[Shaarli](https://github.com/shaarli/Shaarli) is a personal, minimalist,
super-fast, database free, bookmarking service.

Copy `.env-dist` to `.env`, and edit variables accordingly.

 * `SHAARLI_TRAEFIK_HOST` the external domain name to forward from traefik.
 * `SHAARLI_DOCKER_TAG` Shaarli docker tag to use ([available tags](https://shaarli.readthedocs.io/en/master/Docker/#get-and-run-a-shaarli-image))

To start Shaarli, go into the shaarli directory and run `docker-compose up -d`.

## xBrowserSync

[xBrowserSync](http://www.xbrowsersync.org) is a free tool for syncing browser data between different browsers
and devices, built for privacy and anonymity.

Copy `.env-dist` to `.env`, and edit variables accordingly.

 * `XBS_TRAEFIK_HOST` the external domain name to forward from traefik.
 * `DB_USERNAME` a user name of your choosing.
 * `DB_PASSWORD` a password of your choosing.

Optional: copy xbs/api/settings-dist.json to xbs/api/settings.json and edit to
include any custom settings you wish to run on your service. Important:
the db.host value should match the container name of the "db" service in
xbs/docker-compose.yml.

To start xBrowseySync, go into the xbs directory and run `docker-compose up -d`.


## Piwigo

[Piwigo](https://piwigo.org/) is an online photo gallery and manager.

Copy `.env-dist` to `.env` and edit the variables accordingly:

 * `PIWIGO_TRAEFIK_HOST` the external domain name to forward from traefik.
 * `MARIADB_ROOT_PASSWORD` the root mysql password
 * `MARIADB_DATABASE` the mysql database name
 * `MARIADB_USER` the mysql database username
 * `MARIADB_PASSWORD` the mysql user password
 * `TIMEZONE` the timezone, in the format of [TZ database name](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)

To start piwigo, go into the piwigo directory and run `docker-compose up -d`.

When you first start up piwigo, you must immediately configure it, as it is left
open to the world. The database hostname is `db`, which is the name of the
service listed in the docker-compose file.

Note that piwigo has an update mechanism builtin, that must be run periodically,
in addition to updating the docker container image.

## SFTP

This is a fork of [atmoz/sftp](https://github.com/atmoz/sftp), which is more
secure by default: 
 * It allows only SSH keys, no password authentication allowed.
 * All data is stored in named volumes.
 * Automatically imports SSH public keys from the provided GitHub username
(instead of password field).
 * Stores `authorized_keys` in a directory outside the user's chroot
(`/etc/ssh/keys/$USER_authorized_keys`).

### Setup

 * Copy `.env-dist` to `.env`, and edit the `SFTP_PORT` and `SFTP_USERS`
   variables.
 * Examine [docker-compose.yaml](docker-compose.yaml)

To start SFTP, go into the sftp directory and run `docker-compose up -d`.

### Mounting data inside another container

All of the user data is stored in a docker named volume: `sftp_sftp-data`. In
order to access the same data from another container, mount the same volume
name. For example, with the username `ryan`:
```
docker run --rm -it -v sftp_sftp-data:/data debian ls -lha /data/ryan
```

## Syncthing

[Syncthing](https://hub.docker.com/r/syncthing/syncthing) is a continuous file
synchronization program.

Copy `.env-dist` to `.env` and edit the variables accordingly, though the
default values are probably fine.

To start Syncthing, go into the syncthing directory and run `docker-compose up -d`.

To access the Syncthing GUI:
1. Create a tunnel:
   ```
   ssh -L 8384:localhost:8384 root@your.remotehost.com
   ```
2. Visit http://localhost:8384 in a web browser.
