# Dockerized tt-rss using docker-compose

The idea is to provide tt-rss working (and updating) out of the box with minimal fuss.

- [FAQ](https://git.tt-rss.org/fox/ttrss-docker-compose/wiki#faq)

General outline of the configuration is as follows:

 - separate containers (frontend: nginx, database: pgsql, app and updater: php/fpm)
 - tt-rss updates from git master repository on container restart
 - tt-rss source code is stored on a persistent volume so plugins, etc. could be easily added
 - database schema is updated automatically
 - nginx has its http port exposed to the outside
 - feed updates are handled via update daemon started in a separate container (`updater`)
 - optional `backups` container which performs tt-rss database backup once a week

### Installation

#### Edit configuration files:

Copy ``.env-dist`` to ``.env`` and edit any relevant variables you need changed.

You will likely have to change ``TTRSS_SELF_URL_PATH`` which should equal fully qualified tt-rss
URL as seen when opening it in your web browser. If this field is set incorrectly, you will
likely see the correct value in the tt-rss fatal error message.

By default, frontend container binds to `localhost` port `8280`. If you want the container to be
accessible on the net, without using a reverse proxy sharing same host, you will need to
remove ``127.0.0.1:`` from ``HTTP_PORT`` variable in ``.env``.

Please don't rename the services inside `docker-compose.yml` unless you know what you're doing. Web container expects application container to be named `app`, if you rename it and it's not accessible via Docker DNS as `http://app` you will run into 502 errors on startup.

Main configuration file (`config.php`) is rewritten on startup, don't edit it manually. Use [environment variables](https://git.tt-rss.org/fox/ttrss-docker-compose/wiki#how-do-i-set-global-configuration-options) or `config.d` snippets to customize it.

#### Build and start the container

```sh
docker-compose up --build -d
```

See docker-compose documentation for more information and available options.

#### Default login credentials

Username: `admin`, password: `password`

### Updating

Restarting the container will update tt-rss from the origin repository. If database needs to be updated,
tt-rss will prompt you to do so on next page refresh. Normally this happens automatically on container startup.

#### Updating container scripts

Latest tt-rss source code expects latest container scripts and vice versa. Updating both is a good idea.

1. Stop the containers: ``docker-compose down && docker-compose rm``
2. Update scripts from git: ``git pull origin master`` and apply any necessary modifications to ``.env``, etc.
3. Rebuild and start the containers: ``docker-compose up --build``

### Suggestions / bug reports

- [Forum thread](https://community.tt-rss.org/t/docker-compose-tt-rss/2894)
