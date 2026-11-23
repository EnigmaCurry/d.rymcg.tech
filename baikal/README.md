# Baikal

[Baikal](https://sabre.io/baikal/) is a lightweight CalDAV+CardDAV server. 

Run `make config` or copy `.env-dist` to `.env_${DOCKER_CONTEXT}_default`, and edit variables
accordingly.

 * `BAIKAL_TRAEFIK_HOST` to the external domain name forwarded from traefik, eg.
   `cal.example.com`

## The image

There is no published image for current Baikal releases (ckulka's images
stop at 0.10.1), so this project builds its own from `image/`. The first
`make install` builds it on the Docker host; that takes a few minutes.
After changing `BAIKAL_VERSION` or `BAIKAL_HOME_ASSISTANT_FIX`,
rebuild with `make build` (or `make install BUILD=1`) - a plain
`make install` reuses the existing image.

See [image/README.md](image/README.md) for what the image contains and
how to bump the Baikal version.

## Upgrading from 0.10.1

`BAIKAL_VERSION` used to select a Docker image tag (`0.10.1-nginx`); it is
now the Baikal release to build. If your `.env` file still has the old
value, set it to a release such as `0.13.0` and run `make build`, then
`make install`. Until then the build stops with an explanatory error, and
the running container is left alone. Baikal migrates its database on
first start; back up the `baikal_config` and `baikal_data` volumes first.

## Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external authentication on
top of your app.

Run `make install`

Immediately configure the application, it is insecure by default until
you set it up!

Run `make open`
