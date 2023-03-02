# Tiny Tiny RSS

[Tiny Tiny RSS](https://tt-rss.org/) is a free and open source web-based
news feed (RSS/Atom) reader and aggregator.

## Configure

Run `make config` and answer the following questions:

 * Set `TTRSS_TRAEFIK_HOST` set to the domain name for your instance of ttrss.

## Install

Run `make install`

Run `watch make status` and wait for the service to finish starting
and become `healthy` (press Ctrl-C to quit watch).

Run `make open` to open the app.

## Change the password

 * The default username is: `admin`
 * The default password is: `password`

You must change this immediately!
