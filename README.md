# d.rymcg.tech

This is a docker-compose project consisting of Traefik as a TLS HTTPS proxy, and
other various services behind this proxy. Each project is in its own
sub-directory containing its own docker-compose.yaml and .env file. 

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
    ## Connect to the Traefik proxy network:
    networks:
    - traefik-proxy
```

## Traefik

Copy `.env-dist` to `.env` and edit the following:

 * `ACME_CA_SERVER` this is the Let's Encrypt API
   (ACME) server to use, staging, production, private etc. 
   
   * For development/staging use `https://acme-staging-v02.api.letsencrypt.org/directory`
   * For production use `https://acme-v02.api.letsencrypt.org/directory`
   
 * `ACME_CA_EMAIL` this is YOUR email address, where you will receive notices
   from Let's Encrypt regarding your domains and related certificates.

To start traefik, go into the traefik directory and run `docker-compose up -d`

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

Visit the configured domain name in your browser to finish the installation. Choose MySQL/MariaDB for the database, enter the details:

 * Username: nextcloud
 * Database: nextcloud
 * Database host: mariadb
 * Password: same as you configured in .env `MYSQL_PASSWORD`
 
