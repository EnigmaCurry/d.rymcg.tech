# traefik/config

This directory contains config templates for the Traefik static
configuration (`traefik.yml`) and the Traefik dynamic configuration
using the [Traefik File
Provider](https://doc.traefik.io/traefik/providers/file/).

The dynamic configuration is split into two sub-directories:

 * [config-template](config-template) - these templates are
   distributed publicly with this git repository.
 * [user-template](user-template) - these templates are ignored by
   git, and are not published.

Before each startup of Traefik, the static config is rendered to
`/data/config/traefik.yml` and the dynamic config is rendered to the
`/data/config/dynamic` directory. Both are subsequently loaded by
Traefik on start. If you set the `TRAEFIK_FILE_PROVIDER_WATCH=true` in
the Traefik .env file, the file provider will watch for changes in the
`/data/config/dynamic` directory and reload the dynamic config without
needing to restart Traefik.

If you have dynamic configuration that you do not want to permanently
store in this git repository, put them in
[user-template](../user-template) instead (all templates should have a
unique file name, otherwise the user-templates will take precedence
over the config-templates.).
