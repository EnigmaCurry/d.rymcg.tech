# Wordpress for d.rymcg.tech
This is a wordpress implementation for [d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech). 

## About
d.rymcg allows you to easily self host many personal apps and services with traefik routing domains and subdomains to appropriate containers.

## Setup
- Follow the instructions at [d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech).
- Update the Makefile in this repo to point to the d.rymcg.tech repo ROOT on your system.
- `make config`
- `make install`
- `make status`

## Testing / Destroying
- `make destroy` will delete everything in the instance
- `make clean` will delete your configured .env and derived compose files.

## Anti-hotlinking

To enable/disable hotlinking of uploaded images on other website domains, set the following variables in the `.env_{CONTEXT}` file:

 * `WP_ANTI_HOTLINK=true` or `WP_ANTI_HOTLINK=false` to turn on/off
   the anti-hotlinking middleware. (Applies to the
   `/wp-content/upload` path only)
 * `WP_ANTI_HOTLINK_REFERERS_EXTRA` is a comma separated list of
   additional domain names to allow hotlinking from (whitelist).
 * `WP_ANTI_HOTLINK_ALLOW_EMPTY_REFERER=true` or
   `WP_ANTI_HOTLINK_ALLOW_EMPTY_REFERER=false` to turn on/off the
   ability for clients that don't specify any referer to download the
   attachments (eg. RSS readers, curl, or copy/pasting the URL in the
   browser address bar).
