# Wordpress for d.rymcg.tech
This is a wordpress implementation for [d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech). 

## About
d.rymcg allows you to easily self host many personal apps and services with traefik routing domains and subdomains to appropriate containers.

## Setup
- Follow the instructions at [d.rymcg.tech](https://github.com/EnigmaCurry/d.rymcg.tech).
- Update the Makefile in this repo to point to the d.rymcg.tech repo ROOT on your system.
- `make config`

This will ask you some questions to generate the config. Here is a
guide to the answers you should pick depending on which kind of
deployment you want:

 * Public Wordpress (default):

   * Set `WP_TRAEFIK_HOST` to the domain name you want to use.
   * Say `N` to the question about `HTTP Basic Authentication`.
   * Say `Y` or `N` to enable `anti-hotlinking of images`.
   * Allowing clients that send an empty referer is your choice.
   * Say `N` to creating a static HTML wordpress export.

 * Private Wordpress (more secure; with optional **public** HTML snapshot):

   * Set `WP_TRAEFIK_HOST` to the domain name you want to use.
   * Say `Y` to the question about `HTTP Basic Authentication`.
   * Say `Y` or `N` to enable `anti-hotlinking of images` (applicable
     to both private and/or public static websites).
   * Say `N` or `Y` to creating a **public** static HTML wordpress export.

- `make install`
- `make status`
- `make open`

You must immediately configure the wordpress instance in your browser,
setting the site title, and creating the admin account and password.
Try to login (you might need to wait a minute). You should then be
granted into the wordpress dashboard.

## Testing / Destroying

- `make destroy` will delete everything in the instance
- `make clean` will delete your configured .env and derived compose files.

## Anti-hotlinking

To enable/disable hotlinking of uploaded images on other website
domains, answer the appropriate questions from `make config`, or set
the following variables in the `.env_{CONTEXT}` file:

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

## Static HTML

This config includes the ability to generate a static HTML snapshot of
your wodpress site utilizing
[wp2static](https://github.com/WP2Static/wp2static), and hosting it
publicly with a static webserver (nginx). To enable the static
website, answer the appropriate questions from `make config`, or set
the following variables in the `.env_{CONTEXT}` file:

 * `WP_WP2STATIC=true` or `WP_WP2STATIC=false` - to enable/disable the
   static website.
 * `WP_WP2STATIC_VERSION=7.2` - The version of wp2static you want to
   use.
 * `WP_TRAEFIK_HOST_STATIC` - the domain name for the static website.
 * `WP_IP_SOURCERANGE_STATIC=0.0.0.0/0` - The IP whitelist for the static website.

Once deployed, go to the wordpress dashboard to change settings and
enable the plugin:

 * Go to the `Settings` page, click `Permalinks`, choose any one of
   the `Permalink structure` options *other than `Plain`*. (The `?` in
   the Plain option is incompatible with the wp2static crawler, so you
   must choose a different one.). Click `Save Changes`.
 * Go to `Plugins` page, find the `WP2Static` plugin, and click on
   `Activate`.
 * Go to the `WP2Static` settings page (top left).
 * Go to `Options`.
 * Set the `Basic Auth User` and `Basic Auth Password` (Highly
   recommended, but this should only be set *if* you enabled HTTP
   Basic Auth during `make config`. Otherwise you should clear this
   setting as your browser may have autofilled it with your wordpress
   account name/password. Note: this should be the same username and
   password saved in `passwords.json`, for the Traefik HTTP Basic
   Authentication, not necessarily the same as your wordpress
   account.).
 * Set the `Deployment URL` to the same as `WP_TRAEFIK_HOST_STATIC`.
 * Click `Save Options`.
 * Go to `Run`.
 * Click `Generate static site`.
 * Click `Refresh Logs` several times until its finished.

Now you can open the URL to your static website
(`WP_TRAEFIK_HOST_STATIC`), and you should see a static snapshot of
your wordpress site, the contents of which are stored in its own
volume: `wp_wp2static`.
