# Redbean webserver

[Redbean](https://redbean.dev/) is a small webserver, that embeds all
of its dependencies and assets, inside of a single executable zip
file.

## Quickstart

```
make config
```

Customize the default content in
[redbean/html-templates/useful-demo](redbean/html-templates/useful-demo),
or create another directory along side it, and set
`REDBEAN_HTML_TEMPLATE=whatever` in your `.env_{CONTEXT}` file.

```
make install
make open
```

## Setup as a regular webserver

By default, `REDBEAN_TRAEFIK_MODE=public` is set in your
`.env_{CONTEXT}` file, which configures a standard public web server
on the Traefik `websecure` entrypoint.

## Setup as a Traefik error page handler

You can also deploy redbean as a private traefik service that acts as
an error page handler for other Traefik services. This lets you
customize the 404 response (or any other response) page of any Traefik
service, with the error page hosted on redbean.

Set `REDBEAN_TRAEFIK_MODE=service` in your `.env_{CONTEXT}` file.

You can apply the config to individual services or to all of your
services routed through the traefik entrypoint (`websecure`):

### Customize error pages per service

Add the following labels to any project's `docker-compose.instance.yaml`:

```
      #! Custom 404 response through traefik redbean service:
      #@ enabled_middlewares.append("{}-404-custom-error".format(router))
      - "traefik.http.middlewares.(@= router @)-404-custom-error.errors.status=404"
      #! Set the service to the redbean service name (check the traefik dashboard)
      - "traefik.http.middlewares.(@= router @)-404-custom-error.errors.service=redbean-default-web@docker"
      #! Grab the error page from redbean, eg. /404.html
      - "traefik.http.middlewares.(@= router @)-404-custom-error.errors.query=/{status}.html"
```

### Customize error pages for all Traefik services

The [Traefik](../traefik) config has support for customizing the error
pages for all services routed through the `websecure` entrypoint. (ie.
you can have a customized 403,404,500 error page for all your
services.)

Deploy the redbean service instance, and find the service name in the
traefik dashboard (ie. `redbean-default-web@docker`, or something else
if its an instance.)

Set the redbean traefik service name in the Traefik config:

```
make -C ../traefik reconfigure var=TRAEFIK_ERROR_HANDLER_404_SERVICE=redbean-default-web@docker
make -C ../traefik install
```

At the moment, only errors `404`, `403`, and `500` are available to
customize, but you can easily add more by customizing the traefik
templates:
[error-handlers.yml](../traefik/config/config-template/error-handlers.yml),
[.env-dist](../traefik/.env-dist),
[setup.sh](../traefik/config/setup.sh), and
[docker-compose.yaml](../traefik/docker-compose.yaml)).

