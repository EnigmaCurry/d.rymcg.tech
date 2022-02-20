# traefik/config/config-template

This directory should contain your own config templates for the [Traefik File
Provider](https://doc.traefik.io/traefik/providers/file/). The templates are
rendered every single startup, and placed in /data/config for Traefik to load
with its file provider.

No file here should be committed back to the git repository.
