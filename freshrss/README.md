[FreshRSS](https://freshrss.org/) is a self-host RSS aggregator.

Compare with [ttrss](../ttrss)

## Config

Run `make config` or copy `.env-dist` to
`.env_${DOCKER_CONTEXT}_default` and set the vars:

 * `FRESHRSS_TRAEFIK_HOST` the domain name for FreshRSS.
 * `TIME_ZONE` the timezone of the server


Bring up the server : `make install`

Open the browser page: `make open`

Immediately open the URL and finish the installation with the wizard. Choose the
SQLite database type when asked.

