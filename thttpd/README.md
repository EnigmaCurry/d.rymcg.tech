# thttpd

[thttpd](https://www.acme.com/software/thttpd/) is "a simple, small, portable,
fast, and secure HTTP server."

This configuration will bundle thttpd and a small static website into a single
docker image.

## Configure

Put your static website source files into the `./static` directory.

Run `make config`

Answer the questions:

 * `THTTPD_TRAEFIK_HOST` - the domain name for the website.
 * `THTTPD_CACHE_CONTROL` - the setting for the Cache-Control header on files
   served, in seconds. (eg. 60)
 
## Install

Run `make install`

## Open the site

Run `make open`
