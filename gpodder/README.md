# gPodder

[gPodder](https://gpodder.net/) is a libre web service that allows you to manage your
podcast subscriptions and discover new content. If you use multiple devices, you can
synchronize subscriptions and your listening progress. 

Run `make config` or copy `.env-dist` to `.env_${DOCKER_CONTEXT}_default`, and edit these
variables:

 * `GPODDER_TRAEFIK_HOST` the external domain name to forward from traefik for
 the main site.
 * `GPODDER_UID` the UID the docker container should run as
 * `GPODDER_GID` the GID the docker container should run as
 * `GPODDER_PW` password for the gPodder GUI (optional)
 * `GPODDER_TZ` the timezone the container should run as
 * `GPODDER_PORT` the port gPodder should use

Start gPodder: `make install`

Open the app in your browser: `make open`