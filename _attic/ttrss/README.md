# Tiny Tiny RSS

[Tiny Tiny RSS](https://tt-rss.org/) is a free and open source web-based
news feed (RSS/Atom) reader and aggregator.

## Configure

Run `make config` and answer the following questions:

 * Set `TTRSS_TRAEFIK_HOST` set to the domain name for your instance of ttrss.

## Install

Run `DOCKER_BUILDKIT=0 make install`

Setting `DOCKER_BUILDKIT=0` will [avoid this
bug](https://github.com/moby/buildkit/issues/1684) (which, even though it is
closed/resolved, it is still not working right without this fix..)

## Change the password

 * The default username is: `admin`
 * The default password is: `password`
 
You must change this immediately!
