# Nginx

This project contains the [nginx](https://hub.docker.com/_/nginx)
webserver and optional profiles for running PHP scripts with
[php-fpm](https://hub.docker.com/r/bitnami/php-fpm) and optional
postgres database.

## Config

```
make config
```
The [default configuration](.env-dist) disables PHP
(`DOCKER_COMPOSE_PROFILES=` blank), and so by default it is
essentially just a static file server.

The config tool automatically enables or disables the optional
profiles for PHP and PostgreSQL, based on your preferences. To
configure them manually, set the variables in the config file
(`.env_{DOCKER_CONTEXT}_{INSTANCE}`):

 * `DOCKER_COMPOSE_PROFILES` is a comma separated list of profile
   names to enable. These profiles choose the optional features to
   enable. By default, only the `nginx` profile is enabled, so only
   nginx is started. Set `DOCKER_COMPOSE_PROFILES=nginx,php-fpm` to
   enable nginx and PHP. Set
   `DOCKER_COMPOSE_PROFILES=nginx,php-fpm,postgres` to enable nginx,
   php, and postgres. The following optional profiles are provided:
   
   * `nginx` the base Nginx service container (required; do not remove
     this one.)
   * `php-fpm` Enables the PHP service container.
   * `postgres` Enables the Postgres Database container.

 * Set `NGINX_TEMPLATE=php-fpm.template.conf`. This sets the nginx
   template that loads the PHP config.
 * For production, set `NGINX_DEBUG_MODE=false` and for development mode set
   `NGINX_DEBUG_MODE=true`. This will enable printing error tracebacks in
   the browser.

## Install

```
make install
```

```
make open
```

## Redis

Redis is automatically activated along when the `php-fpm` profile is
selected. Redis is setup to save the PHP session info by default.

Redis requires the sysctl setting `vm.overcommit_memory=1`, which must
be set *on the Docker host*:

```
# Run this on the Docker host to enable overcommit_memory:
echo "vm.overcommit_memory=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

Without this setting, you may see the warning message in the logs:

```
WARNING Memory overcommit must be enabled! Without it, a background save or 
replication may fail under low memory condition. Being disabled, it can can
also cause failures without low memory condition, see
https://github.com/jemalloc/jemalloc/issues/1328. 
```

