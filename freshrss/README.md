[FreshRSS](https://freshrss.org/) is a self-host RSS aggregator.

Compare with [ttrss](../ttrss)

## Config

Copy `.env-dist` to `.env` and set the vars:

 * `FRESHRSS_TRAEFIK_HOST` the domain name for FreshRSS.
 * `TIME_ZONE` the timezone of the server


Bring up the server with `docker-compose up -d`

Immediately open the URL and finish the installation with the wizard. Choose the
SQLite database type when asked.

