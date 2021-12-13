# Tiny Tiny RSS

[Tiny Tiny RSS](https://tt-rss.org/) is a free and open source web-based
news feed (RSS/Atom) reader and aggregator.

[ttrss-docker-compose](https://git.tt-rss.org/fox/ttrss-docker-compose.git) was
copied into the `ttrss` directory and some light modifications were made to its
docker-compose file to get it to work with traefik. Follow the upstream [ttrss
README](ttrss/README.md) which is still unmodified, but also consider these
additions for usage with Traefik:

Copy `.env-dist` to `.env`, and edit variables accordingly. 

 * Set `TTRSS_TRAEFIK_HOST` (this is a new custom variable not in the upstream
   version) to the external domain name you want to forward in from traefik.
   Example: `tt-rss.example.com` (just the domain part, no https:// prefix and
   no port number)
 * Set `TTRSS_SELF_URL_PATH` with the full URL of the app, eg.
   `https://tt-rss.example.com/tt-rss` (The path `/tt-rss` at the end is
   required, but the root domain will automatically forward to this.)
 * Setting `HTTP_PORT` is unnecessary and is now ignored.
 
To start TT-RSS, go into the ttrss directory and run `docker-compose up -d`. 
