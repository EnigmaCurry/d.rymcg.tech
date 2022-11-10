# traefik/config

This directory contains config templates for the Traefik static
configuration ([traefik.yml](traefik.yml)) and the Traefik dynamic
configuration
([config-template](https://github.com/EnigmaCurry/d.rymcg.tech/tree/traefik-host-networking/traefik/config/config-template))using
the [Traefik File
Provider](https://doc.traefik.io/traefik/providers/file/).

The dynamic configuration is split into two sub-directories:

 * [config-template](config-template) - these templates are
   distributed publicly with this git repository.
 * [user-template](user-template) - these templates are ignored by
   git, and are not published.

Before each startup of Traefik, [setup.sh](setup.sh) renders the
static config to `/data/config/traefik.yml` and the dynamic config to
the `/data/config/dynamic` directory. Both are subsequently loaded by
Traefik on start. If you set the `TRAEFIK_FILE_PROVIDER_WATCH=true` in
the Traefik .env file, the file provider will watch for changes in the
`/data/config/dynamic` directory and reload the dynamic config without
needing to restart Traefik.

If you have dynamic configuration that you do not want to permanently
store in this git repository, put them in
[user-template](user-template) instead (all templates should have a
unique file name, otherwise the user-templates will take precedence
over the config-templates.).

Dynamic configuration may also come from the [Docker
provider](https://doc.traefik.io/traefik/providers/docker/) via docker
labels on the service containers. This can be turned off by setting
`TRAEFIK_DOCKER_PROVIDER=false`.
