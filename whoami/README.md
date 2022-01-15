# whoami

[whoami](https://github.com/traefik/whoami) is a tiny Go webserver that prints
os information and HTTP request to output.

The [docker-compose.yaml](docker-compose.yaml) contains several examples of
Traefik middleware, and can be used as a template for other services.

## Config

```
make config
```

Or you can just edit `.env` directly, set `WHOAMI_TRAEFIK_HOST` to the domain
you want to host the `whoami` service on.


## Start

```
make install
```

Or you can just run `docker-compose up -d`

## Stop

```
make stop
```

Or you can just run `docker-compose down`

