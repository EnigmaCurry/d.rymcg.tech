# traefik/config

This directory contains config templates for the Traefik static
configuration ([traefik.yml](traefik.yml)) and the Traefik dynamic
configuration
([config-template](https://github.com/EnigmaCurry/d.rymcg.tech/tree/traefik-host-networking/traefik/config/config-template))using
the [Traefik File
Provider](https://doc.traefik.io/traefik/providers/file/).

The dynamic configuration is split into two sub-directories:

 * [config-template](config-template) - these templates are
   distributed publicly with this git repository, and apply to all
   installations, as configured.
 * [context-template](context-template) - these templates are ignored
   by git, are not published, and are specific to individual instances
   (Docker contexts). You can put your own context-specific config
   into separate sub-directories, named after each context.

Before each startup of Traefik, [setup.sh](setup.sh) renders the
static config to `/data/config/traefik.yml` and the dynamic config to
the `/data/config/dynamic` directory. Both are subsequently loaded by
Traefik on start. If you set the `TRAEFIK_FILE_PROVIDER_WATCH=true` in
the Traefik .env file, the file provider will watch for changes in the
`/data/config/dynamic` directory and reload the dynamic config without
needing to restart Traefik.

Dynamic configuration may also come from the [Docker
provider](https://doc.traefik.io/traefik/providers/docker/) via docker
labels on the service containers. This can be turned off by setting
`TRAEFIK_DOCKER_PROVIDER=false`.

If you have dynamic configuration that you do not want to permanently
store in this git repository, put it in
[context-template](context-template), within another sub-directory
named after the docker context (eg. `./context-template/foo/bar.yml`
for the docker context named `foo`, and this would get written to
`/data/config/dynamic/foo/bar.yml` in the traefik volume). Other
sub-directories of `context-template`, that are named differently than
the current Docker context, are *not* copied to the traefik volume.
