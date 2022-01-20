# Tiny Tiny RSS

[Tiny Tiny RSS](https://tt-rss.org/) is a free and open source web-based
news feed (RSS/Atom) reader and aggregator.

Copy `.env-dist` to `.env`, and edit variables accordingly. 

 * Set `TTRSS_TRAEFIK_HOST` set to the domain name for your instance of ttrss.
 * Set `TTRSS_DATABASE_PASSWORD` Create a secure passphrase for the database.

To start ttrss, go into the ttrss directory and run `docker-compose up -d`.

## Change the password

 * The default username is: `admin`
 * The default password is: `password`
 
You must change this immediately!
